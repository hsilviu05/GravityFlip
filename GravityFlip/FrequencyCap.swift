import Foundation

/// All interstitial frequency-cap rules enforced in one testable value type.
/// Inject a custom clock closure to control time in unit tests.
struct FrequencyCapPolicy {
    var clock: () -> Date

    private(set) var totalRunCount: Int = 0
    private(set) var deathsSinceLastInterstitial: Int = 0
    private(set) var lastInterstitialDate: Date?
    private(set) var lastRewardedDate: Date?

    init(clock: @escaping () -> Date = { Date() }) {
        self.clock = clock
    }

    mutating func recordRunStarted()        { totalRunCount += 1 }
    mutating func recordDeath()             { deathsSinceLastInterstitial += 1 }

    mutating func recordInterstitialShown() {
        lastInterstitialDate = clock()
        deathsSinceLastInterstitial = 0
    }

    mutating func recordRewardedShown() {
        lastRewardedDate = clock()
    }

    /// Returns true when ALL of the following hold:
    /// - at least 3 runs have started
    /// - at least 2 deaths since the last interstitial (or ever)
    /// - 60 s elapsed since the last interstitial
    /// - 5 s elapsed since the last rewarded ad
    func canShowInterstitial() -> Bool {
        guard totalRunCount >= 3 else { return false }
        guard deathsSinceLastInterstitial >= 2 else { return false }
        let now = clock()
        if let last = lastInterstitialDate, now.timeIntervalSince(last) < 60  { return false }
        if let last = lastRewardedDate,    now.timeIntervalSince(last) < 5    { return false }
        return true
    }
}
