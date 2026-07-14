import SwiftUI
import GoogleMobileAds

/// Adaptive banner that collapses to zero height when there is no fill or when
/// the user has purchased Remove Ads.
struct AdBannerView: View {
    @ObservedObject private var storeMgr = StoreManager.shared
    @StateObject  private var loader     = BannerLoader()

    var body: some View {
        Group {
            if !storeMgr.adsRemoved && loader.height > 0 {
                _BannerRepresentable(bannerView: loader.banner)
                    .frame(height: loader.height)
            }
        }
        .onAppear {
            if !storeMgr.adsRemoved { loader.load() }
        }
    }
}

// MARK: - Internals

private final class BannerLoader: NSObject, BannerViewDelegate, ObservableObject {
    @Published var height: CGFloat = 0
    let banner: BannerView
    private var loaded = false

    override init() {
        banner = BannerView()
        super.init()
        banner.adUnitID = AdConfig.bannerAdUnitID
        banner.delegate = self
    }

    func load() {
        guard !loaded else { return }
        loaded = true

        let width = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .screen.bounds.width ?? 390

        guard let root = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow))?.rootViewController else { return }

        banner.rootViewController = root
        banner.adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        banner.load(Request())
    }

    // MARK: BannerViewDelegate

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        DispatchQueue.main.async { self.height = bannerView.adSize.size.height }
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        DispatchQueue.main.async { self.height = 0 }
    }
}

private struct _BannerRepresentable: UIViewRepresentable {
    let bannerView: BannerView
    func makeUIView(context: Context) -> BannerView { bannerView }
    func updateUIView(_ uiView: BannerView, context: Context) {}
}
