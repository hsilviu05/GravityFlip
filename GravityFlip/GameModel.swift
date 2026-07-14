import Foundation
import CoreGraphics

enum GamePhase: Equatable { case menu, playing, dead }

final class GameModel: ObservableObject {
    @Published private(set) var phase:          GamePhase = .menu
    @Published private(set) var score:          Double    = 0
    @Published private(set) var coins:          Int       = 0
    @Published private(set) var highScore:      Double    = 0
    @Published private(set) var totalCoins:     Int       = 0
    @Published private(set) var elapsed:        Double    = 0
    @Published private(set) var alreadyContinued = false
    @Published private(set) var coinsDoubled     = false
    @Published private(set) var isNewBest        = false

    private static let highScoreKey  = "fs_highScore"
    private static let totalCoinsKey = "fs_totalCoins"

    init() {
        highScore  = UserDefaults.standard.double(forKey: Self.highScoreKey)
        totalCoins = UserDefaults.standard.integer(forKey: Self.totalCoinsKey)
    }

    // MARK: - Difficulty (queried by GameScene each frame)

    var speedMultiplier: Double {
        let steps = Int(elapsed / Tuning.speedStepInterval)
        return min(pow(Double(Tuning.speedStepFactor), Double(steps)),
                   Double(Tuning.speedCapMultiplier))
    }

    var currentSpeed: CGFloat {
        CGFloat(Double(Tuning.baseSpeed) * speedMultiplier)
    }

    var spawnInterval: TimeInterval {
        let t = min(elapsed / Tuning.spawnDecayTime, 1.0)
        return Tuning.baseSpawnInterval
             - (Tuning.baseSpawnInterval - Tuning.minSpawnInterval) * t
    }

    var pinchProbability: Double {
        if elapsed < Tuning.pinchUnlockTime { return 0 }
        if elapsed < 40 { return Tuning.pinchProbStage1 }
        return Tuning.pinchProbStage2
    }

    // MARK: - Lifecycle

    func startRun() {
        if phase == .dead { commitCoins() }
        score = 0; coins = 0; elapsed = 0
        alreadyContinued = false
        coinsDoubled     = false
        isNewBest        = false
        phase = .playing
    }

    func update(dt: Double) {
        guard phase == .playing else { return }
        elapsed += dt
        score += Double(currentSpeed) * dt * Tuning.scoreScale
    }

    func collectCoin() {
        guard phase == .playing else { return }
        coins += Tuning.coinValue
    }

    func returnToMenu() {
        if phase == .dead { commitCoins() }
        phase = .menu
    }

    func die() {
        guard phase == .playing else { return }
        phase = .dead
        isNewBest = score > highScore
        if isNewBest {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: Self.highScoreKey)
        }
        AdManager.shared.recordDeath()
        GameCenterManager.shared.submitScore(Int(score))
        // Coins are NOT committed here — doubleCoins() may still be called.
    }

    /// Resume the current run after watching a rewarded ad. Can only be used once per run.
    func continueRun() {
        guard phase == .dead, !alreadyContinued else { return }
        alreadyContinued = true
        phase = .playing
    }

    /// Double the coins earned this run before they are committed to totalCoins.
    func doubleCoins() {
        guard phase == .dead, !coinsDoubled else { return }
        coinsDoubled = true
        coins *= 2
    }

    // MARK: - Private

    private func commitCoins() {
        totalCoins += coins
        UserDefaults.standard.set(totalCoins, forKey: Self.totalCoinsKey)
    }
}
