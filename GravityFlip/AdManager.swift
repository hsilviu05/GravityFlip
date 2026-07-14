import Foundation
import GoogleMobileAds
import Network
import AppTrackingTransparency
import UIKit

/// Central ad service. Every public method is safe to call in airplane mode or
/// before any ad has loaded — it silently no-ops / returns false / calls completion immediately.
final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    @Published private(set) var isInterstitialReady = false
    @Published private(set) var isRewardedReady     = false

    var policy = FrequencyCapPolicy()   // internal visibility for testing

    // MARK: - Private state

    private var interstitial: InterstitialAd?
    private var rewardedAd:   RewardedAd?

    private let pathMonitor = NWPathMonitor()
    private var isConnected = false

    private var attDone           = false
    private var firstGameOverDone = false

    private var pendingInterstitialCompletion: (() -> Void)?
    private var pendingRewardedCompletion:     (() -> Void)?

    private override init() {
        super.init()
        startNetworkMonitoring()
    }

    // MARK: - Initialise SDK (call once at app launch)

    func initialize() {
        MobileAds.shared.start(completionHandler: nil)
    }

    // MARK: - Network monitoring

    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? false
                self?.isConnected = path.status == .satisfied
                if !wasConnected && path.status == .satisfied {
                    self?.preloadIfNeeded()
                }
            }
        }
        pathMonitor.start(queue: .global(qos: .utility))
    }

    private func preloadIfNeeded() {
        if interstitial == nil { loadInterstitial() }
        if rewardedAd   == nil { loadRewarded() }
    }

    // MARK: - ATT (request after first game-over, never at launch)

    func notifyFirstGameOver() {
        guard !firstGameOverDone else { return }
        firstGameOverDone = true
        guard !attDone else { return }
        attDone = true
        ATTrackingManager.requestTrackingAuthorization { _ in
            // AdMob reads ATT status itself; no action needed here.
        }
    }

    // MARK: - Frequency-cap hooks (called by the coordinator)

    func recordRunStarted() { policy.recordRunStarted() }
    func recordDeath()      { policy.recordDeath() }

    // MARK: - Load

    private func loadInterstitial() {
        guard isConnected else { return }
        InterstitialAd.load(
            with: AdConfig.interstitialAdUnitID,
            request: Request()
        ) { [weak self] ad, _ in
            DispatchQueue.main.async {
                self?.interstitial = ad
                self?.interstitial?.fullScreenContentDelegate = self
                self?.isInterstitialReady = ad != nil
            }
        }
    }

    private func loadRewarded() {
        guard isConnected else { return }
        RewardedAd.load(
            with: AdConfig.rewardedAdUnitID,
            request: Request()
        ) { [weak self] ad, _ in
            DispatchQueue.main.async {
                self?.rewardedAd = ad
                self?.rewardedAd?.fullScreenContentDelegate = self
                self?.isRewardedReady = ad != nil
            }
        }
    }

    // MARK: - Show interstitial

    /// Attempts to show an interstitial if all frequency-cap rules are satisfied.
    /// `completion` is called immediately if no ad is shown, or after the ad is dismissed.
    /// Always a no-op (calls completion immediately) when the user has purchased Remove Ads.
    func tryShowInterstitial(from vc: UIViewController, completion: @escaping () -> Void) {
        guard !StoreManager.adsRemovedFast,
              policy.canShowInterstitial(),
              let ad = interstitial, isInterstitialReady else {
            completion()
            return
        }
        policy.recordInterstitialShown()
        interstitial = nil
        isInterstitialReady = false
        pendingInterstitialCompletion = completion
        ad.present(from: vc)
        if isConnected { loadInterstitial() }
    }

    // MARK: - Show rewarded

    /// Presents a rewarded ad. `completion(true)` fires if the user earned the reward;
    /// `completion(false)` fires if no ad was ready or the user did not complete it.
    func showRewarded(from vc: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let ad = rewardedAd, isRewardedReady else {
            completion(false)
            return
        }
        rewardedAd = nil
        isRewardedReady = false

        // `earned` is captured by both closures; the reward handler runs first (during
        // playback), then adDidDismiss fires and delivers the result.
        var earned = false
        ad.present(from: vc) { [weak self] in
            earned = true
            self?.policy.recordRewardedShown()
        }
        pendingRewardedCompletion = { completion(earned) }
        if isConnected { loadRewarded() }
    }
}

// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if ad is InterstitialAd {
            let c = pendingInterstitialCompletion
            pendingInterstitialCompletion = nil
            c?()
        } else {
            let c = pendingRewardedCompletion
            pendingRewardedCompletion = nil
            c?()
        }
    }

    func ad(_ ad: FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        if ad is InterstitialAd {
            interstitial = nil
            isInterstitialReady = false
            let c = pendingInterstitialCompletion
            pendingInterstitialCompletion = nil
            c?()                          // proceed even on failure
            if isConnected { loadInterstitial() }
        } else {
            rewardedAd = nil
            isRewardedReady = false
            let c = pendingRewardedCompletion
            pendingRewardedCompletion = nil
            c?()                          // earned == false
            if isConnected { loadRewarded() }
        }
    }
}
