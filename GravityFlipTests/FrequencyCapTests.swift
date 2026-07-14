import XCTest
@testable import GravityFlip

// Reference-type clock: mutations are visible inside the escaping closure.
private final class TestClock {
    var now: Date
    init(_ date: Date = Date(timeIntervalSinceReferenceDate: 10_000)) { self.now = date }
    func advance(by seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

final class FrequencyCapTests: XCTestCase {

    // MARK: - Helpers

    /// Policy with 3 runs + 2 deaths already recorded (minimum to show).
    private func eligiblePolicy(clock: TestClock) -> FrequencyCapPolicy {
        var p = FrequencyCapPolicy(clock: { clock.now })
        p.recordRunStarted(); p.recordRunStarted(); p.recordRunStarted()
        p.recordDeath();      p.recordDeath()
        return p
    }

    // MARK: - Run count gate

    func testBlockedBeforeThreeRuns() {
        var p = FrequencyCapPolicy()
        p.recordRunStarted(); p.recordRunStarted()   // only 2
        p.recordDeath();      p.recordDeath()
        XCTAssertFalse(p.canShowInterstitial(), "must reach 3 runs first")

        p.recordRunStarted()
        XCTAssertTrue(p.canShowInterstitial())
    }

    // MARK: - Death count gate (max 1 interstitial per 2 deaths)

    func testBlockedWithOneDeath() {
        var p = FrequencyCapPolicy()
        p.recordRunStarted(); p.recordRunStarted(); p.recordRunStarted()
        p.recordDeath()          // only 1
        XCTAssertFalse(p.canShowInterstitial(), "need 2 deaths")

        p.recordDeath()
        XCTAssertTrue(p.canShowInterstitial())
    }

    func testDeathCountResetsAfterInterstitial() {
        let clock = TestClock()
        var p = eligiblePolicy(clock: clock)

        p.recordInterstitialShown()

        // 60 s pass, 1 death — still blocked (need 2 since last interstitial)
        clock.advance(by: 61)
        p.recordDeath()
        XCTAssertFalse(p.canShowInterstitial())

        p.recordDeath()
        XCTAssertTrue(p.canShowInterstitial())
    }

    // MARK: - 60 s cooldown between interstitials

    func testSixtySecondMinimumBetweenShows() {
        let clock = TestClock()
        var p = eligiblePolicy(clock: clock)

        p.recordInterstitialShown()
        clock.advance(by: 61)
        // Deaths were reset; need 2 more before we can check cooldown
        p.recordDeath(); p.recordDeath()

        // Rewind and test at exactly 59 s
        let clock2 = TestClock()
        var p2 = eligiblePolicy(clock: clock2)
        p2.recordInterstitialShown()
        p2.recordDeath(); p2.recordDeath()

        clock2.advance(by: 59)
        XCTAssertFalse(p2.canShowInterstitial(), "blocked at 59 s")

        clock2.advance(by: 1.1)
        XCTAssertTrue(p2.canShowInterstitial(), "allowed at 60+ s")
    }

    // MARK: - 5 s cooldown after rewarded ad

    func testBlockedWithin5sOfRewardedAd() {
        let clock = TestClock()
        var p = eligiblePolicy(clock: clock)

        p.recordRewardedShown()

        clock.advance(by: 4.9)
        XCTAssertFalse(p.canShowInterstitial(), "blocked within 5 s of rewarded")

        clock.advance(by: 0.2)
        XCTAssertTrue(p.canShowInterstitial(), "allowed after 5 s")
    }

    // MARK: - Airplane-mode safety

    func testPolicyHasNoNetworkDependency() {
        // FrequencyCapPolicy has zero knowledge of network state.
        var p = FrequencyCapPolicy()
        p.recordRunStarted(); p.recordRunStarted(); p.recordRunStarted()
        p.recordDeath(); p.recordDeath()
        XCTAssertTrue(p.canShowInterstitial())   // no crash, no network check
    }

    // MARK: - All conditions must hold simultaneously

    func testAllConditionsMustBeSatisfied() {
        let clock = TestClock()
        var p = eligiblePolicy(clock: clock)

        // Rewarded just shown → 5 s cooldown blocks
        p.recordRewardedShown()
        XCTAssertFalse(p.canShowInterstitial(), "rewarded cooldown blocks")

        clock.advance(by: 5.1)
        XCTAssertTrue(p.canShowInterstitial(), "all clear after rewarded cooldown")
    }
}
