import Foundation
import CoreGraphics

// All gameplay tuning lives here. Change numbers, re-run — nothing else to touch.
enum Tuning {

    // MARK: - Speed / difficulty

    /// Base world scroll speed at run start (pts/s).
    static let baseSpeed: CGFloat = 175
    /// Hard cap: speed never exceeds base × this.
    static let speedCapMultiplier: CGFloat = 2.2
    /// How often speed steps up.
    static let speedStepInterval: TimeInterval = 10
    /// Multiplier applied per step (5%).
    static let speedStepFactor: CGFloat = 1.05

    // MARK: - Flip arc

    /// Time for player to arc from one surface to the other (seconds).
    static let flipDuration: TimeInterval = 0.25

    // MARK: - Player

    static let playerRadius: CGFloat = 11
    /// Horizontal position as fraction of scene width.
    static let playerXFraction: CGFloat = 0.22
    /// Inward shrink applied to player radius for hit detection (forgiveness).
    static let playerHitShrink: CGFloat = 2

    // MARK: - Corridor / surfaces

    static let surfaceThickness: CGFloat = 5

    // MARK: - Spikes

    static let spikeWidth: CGFloat = 36
    /// Height of a single (non-pinch) spike.
    static let spikeHeight: CGFloat = 52
    /// Hitbox = visual size × this (< 1 → more forgiving).
    static let spikeHitFraction: CGFloat = 0.73
    /// Gap between opposing spike tips in a pinch pattern (pts).
    static let pinchGapTarget: CGFloat = 88

    // MARK: - Spawning

    static let baseSpawnInterval: TimeInterval = 2.1
    static let minSpawnInterval: TimeInterval = 0.90
    /// Time (s) to linearly interpolate from base to min spawn interval.
    static let spawnDecayTime: TimeInterval = 55

    // MARK: - Pattern availability (by elapsed time)

    static let pinchUnlockTime: TimeInterval = 18
    static let pinchProbStage1: Double = 0.18   // 18–40 s
    static let pinchProbStage2: Double = 0.38   // 40 s+

    // MARK: - Coins

    static let coinRadius: CGFloat = 8
    static let coinValue: Int = 1
    static let coinSpawnChance: Double = 0.28
    /// Distance from surface to coin center (pts).
    static let coinSurfaceOffset: CGFloat = 32

    // MARK: - Score

    /// score += scrollDistance × this each frame.
    static let scoreScale: Double = 1.0 / 48

    // MARK: - Player trail

    /// Spawn a ghost every N update frames.
    static let trailFrameInterval: Int = 3
    static let trailFadeDuration: TimeInterval = 0.20
    static let trailStartAlpha: CGFloat = 0.38

    // MARK: - Particles

    static let deathParticleCount: Int = 24
    static let deathParticleMinSpeed: CGFloat = 70
    static let deathParticleMaxSpeed: CGFloat = 210
    static let deathParticleLife: TimeInterval = 0.55

    static let coinParticleCount: Int = 10
    static let coinParticleMinSpeed: CGFloat = 55
    static let coinParticleMaxSpeed: CGFloat = 130
    static let coinParticleLife: TimeInterval = 0.35

    // MARK: - Camera shake

    static let shakeAmplitude: CGFloat = 7
}
