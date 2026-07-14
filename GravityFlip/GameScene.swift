import SpriteKit
import UIKit

final class GameScene: SKScene {

    weak var gameModel: GameModel?

    // MARK: - Layout (valid after didMove)

    private var playerXPos: CGFloat = 0
    private var playerFloorY: CGFloat = 0
    private var playerCeilingY: CGFloat = 0

    // MARK: - Player

    private var playerNode: SKShapeNode!

    private enum Surface { case floor, ceiling }

    private enum FlipState {
        case resting(Surface)
        case flipping(from: Surface, progress: CGFloat)
    }

    private var flipState: FlipState = .resting(.floor)
    private var flipFromY: CGFloat = 0
    private var flipToY: CGFloat = 0

    // MARK: - Active entities

    private struct SpikeData {
        let node: SKShapeNode
        let isFloor: Bool
        let visualHeight: CGFloat
    }

    private struct CoinData {
        let node: SKShapeNode
        var collected = false
    }

    private var spikes: [SpikeData] = []
    private var coins: [CoinData] = []

    // MARK: - Camera

    private var gameCamera: SKCameraNode!

    // MARK: - Trail

    private var trailFrameCount = 0
    private var trailTexture: SKTexture?

    // MARK: - Particles

    private var deathTextures: [SKTexture] = []
    private var coinTexture: SKTexture?

    // MARK: - Haptics

    private let impactLight  = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy  = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: - Run bookkeeping

    private var isRunActive = false
    private var spawnTimer: TimeInterval = 0
    private var lastTime: TimeInterval = 0
    private var runStartDate: Date = .distantPast

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1)

        let sT = Tuning.surfaceThickness
        playerXPos     = size.width  * Tuning.playerXFraction
        playerFloorY   = sT + Tuning.playerRadius
        playerCeilingY = size.height - sT - Tuning.playerRadius

        setupCamera()
        buildSurfaces()
        buildPlayer()
        buildTextureCache()
        resetPlayerToFloor()
        observeLifecycle()
    }

    private func setupCamera() {
        gameCamera = SKCameraNode()
        gameCamera.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(gameCamera)
        camera = gameCamera
    }

    private func buildSurfaces() {
        let sT = Tuning.surfaceThickness
        let w  = size.width

        func makeSurface(centeredAtY y: CGFloat) -> SKShapeNode {
            let n = SKShapeNode(rectOf: CGSize(width: w, height: sT))
            n.fillColor = SKColor(red: 0.55, green: 0.80, blue: 1.0, alpha: 1)
            n.strokeColor = .clear
            n.position = CGPoint(x: w / 2, y: y)
            return n
        }

        addChild(makeSurface(centeredAtY: sT / 2))
        addChild(makeSurface(centeredAtY: size.height - sT / 2))
    }

    private func buildPlayer() {
        playerNode = SKShapeNode(circleOfRadius: Tuning.playerRadius)
        playerNode.fillColor = SKColor(red: 0.25, green: 0.95, blue: 1.0, alpha: 1)
        playerNode.strokeColor = .white
        playerNode.lineWidth = 1.5
        playerNode.zPosition = 2
        addChild(playerNode)
    }

    private func buildTextureCache() {
        trailTexture = circleTexture(radius: Tuning.playerRadius,
                                     color: UIColor(red: 0.25, green: 0.95, blue: 1.0, alpha: 1))
        deathTextures = [
            circleTexture(radius: 5, color: UIColor(red: 1.0, green: 0.22, blue: 0.10, alpha: 1)),
            circleTexture(radius: 4, color: UIColor(red: 1.0, green: 0.50, blue: 0.10, alpha: 1)),
            circleTexture(radius: 3, color: UIColor(red: 1.0, green: 0.72, blue: 0.20, alpha: 1))
        ]
        coinTexture = circleTexture(radius: 4,
                                    color: UIColor(red: 1.0, green: 0.88, blue: 0.10, alpha: 1))
    }

    private func circleTexture(radius: CGFloat, color: UIColor) -> SKTexture {
        let size = CGSize(width: radius * 2, height: radius * 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            color.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        }
        return SKTexture(image: image)
    }

    private func observeLifecycle() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(appWillResign),
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func appWillResign() {
        guard gameModel?.phase == .playing else { return }
        isPaused = true
    }

    @objc private func appDidBecomeActive() {
        guard gameModel?.phase == .playing else { return }
        isPaused = false
        lastTime = 0   // reset so dt doesn't spike on resume
    }

    // MARK: - Reset

    func resetForNewRun() {
        clearEntities()
        resetPlayerToFloor()
        trailFrameCount = 0
        spawnTimer  = 0
        lastTime    = 0
        isRunActive = true
        runStartDate = Date()
        resetCamera()
        impactMedium.prepare()
        impactLight.prepare()
        impactHeavy.prepare()
    }

    func prepareForMenu() {
        clearEntities()
        isRunActive = false
        resetPlayerToFloor()
        resetCamera()
    }

    /// Called after the player watches a rewarded ad to continue the run.
    /// Clears obstacles in the safe zone ahead, resets the player to floor,
    /// and resumes the run loop without touching score/elapsed/coins.
    func resurrectPlayer() {
        // Remove spikes close to or ahead of the player so they don't instant-die again.
        let safeAheadPx: CGFloat = 220
        spikes.removeAll {
            let dx = $0.node.position.x - playerXPos
            guard dx > -30 && dx < safeAheadPx else { return false }
            $0.node.removeFromParent()
            return true
        }

        resetPlayerToFloor()

        // Brief blink to signal invincibility window, then resume.
        let blink = SKAction.sequence([
            .fadeAlpha(to: 0.35, duration: 0.08),
            .fadeAlpha(to: 1.00, duration: 0.08)
        ])
        playerNode.run(.sequence([.repeat(blink, count: 4)]))

        spawnTimer = 0     // full spawn-interval grace before next obstacle
        lastTime   = 0     // prevent dt spike
        isRunActive = true
    }

    private func clearEntities() {
        for s in spikes { s.node.removeFromParent() }
        for c in coins  { c.node.removeFromParent() }
        spikes.removeAll()
        coins.removeAll()
    }

    private func resetPlayerToFloor() {
        playerNode.position = CGPoint(x: playerXPos, y: playerFloorY)
        playerNode.setScale(1)
        playerNode.removeAllActions()
        playerNode.fillColor = SKColor(red: 0.25, green: 0.95, blue: 1.0, alpha: 1)
        flipState = .resting(.floor)
        flipFromY = 0; flipToY = 0
    }

    private func resetCamera() {
        gameCamera.removeAction(forKey: "shake")
        gameCamera.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    // MARK: - Input (tap-DOWN for zero perceived latency)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameModel?.phase == .playing, isRunActive, !isPaused else { return }
        guard Date().timeIntervalSince(runStartDate) > 0.22 else { return }
        attemptFlip()
    }

    private func attemptFlip() {
        guard case .resting(let surface) = flipState else { return }

        let goingUp = (surface == .floor)
        flipFromY = playerNode.position.y
        flipToY   = goingUp ? playerCeilingY : playerFloorY
        flipState = .flipping(from: surface, progress: 0)

        let (sx, sy): (CGFloat, CGFloat) = goingUp ? (0.65, 1.35) : (1.35, 0.65)
        playerNode.run(.sequence([
            .scaleX(to: sx, y: sy, duration: 0.055),
            .scale(to: 1.0, duration: 0.10)
        ]), withKey: "squash")

        SoundManager.shared.playFlip()
    }

    // MARK: - Main update loop

    override func update(_ currentTime: TimeInterval) {
        guard let model = gameModel, model.phase == .playing, isRunActive else {
            lastTime = currentTime
            return
        }

        let dt: CGFloat = lastTime == 0
            ? 0
            : CGFloat(min(currentTime - lastTime, 1.0 / 30))
        lastTime = currentTime
        guard dt > 0 else { return }

        model.update(dt: Double(dt))
        advanceFlip(dt: dt)
        spawnTrailGhost()
        scrollWorld(speed: model.currentSpeed, dt: dt)
        cullOffscreen()
        trySpawn(dt: dt, model: model)
        detectCollisions(model: model)
    }

    // MARK: - Player arc (sin-eased)

    private func advanceFlip(dt: CGFloat) {
        switch flipState {
        case .resting(let surface):
            playerNode.position.y = surface == .floor ? playerFloorY : playerCeilingY

        case .flipping(let fromSurface, let progress):
            let newProgress = progress + dt / CGFloat(Tuning.flipDuration)

            if newProgress >= 1 {
                let land: Surface = fromSurface == .floor ? .ceiling : .floor
                playerNode.position.y = land == .floor ? playerFloorY : playerCeilingY
                flipState = .resting(land)
                playLandingSquash(on: land)
            } else {
                flipState = .flipping(from: fromSurface, progress: newProgress)
                let t = (1 - cos(.pi * newProgress)) / 2
                playerNode.position.y = flipFromY + (flipToY - flipFromY) * t
            }
        }
    }

    private func playLandingSquash(on surface: Surface) {
        let (sx, sy): (CGFloat, CGFloat) = surface == .floor ? (1.35, 0.65) : (0.65, 1.35)
        playerNode.run(.sequence([
            .scaleX(to: sx, y: sy, duration: 0.05),
            .scale(to: 1.0, duration: 0.09)
        ]), withKey: "squash")
        if SettingsManager.shared.hapticsEnabled { impactMedium.impactOccurred() }
        SoundManager.shared.playLand()
    }

    // MARK: - Trail

    private func spawnTrailGhost() {
        trailFrameCount += 1
        guard trailFrameCount % Tuning.trailFrameInterval == 0,
              let tex = trailTexture else { return }

        let ghost = SKSpriteNode(texture: tex)
        ghost.alpha = Tuning.trailStartAlpha
        ghost.position = playerNode.position
        ghost.xScale = playerNode.xScale
        ghost.yScale = playerNode.yScale
        ghost.zPosition = playerNode.zPosition - 1
        addChild(ghost)

        ghost.run(.sequence([
            .group([
                .fadeOut(withDuration: Tuning.trailFadeDuration),
                .scale(to: 0.55, duration: Tuning.trailFadeDuration)
            ]),
            .removeFromParent()
        ]))
    }

    // MARK: - Scroll

    private func scrollWorld(speed: CGFloat, dt: CGFloat) {
        let dx = speed * dt
        for s in spikes { s.node.position.x -= dx }
        for i in coins.indices { coins[i].node.position.x -= dx }
    }

    private func cullOffscreen() {
        spikes.removeAll {
            guard $0.node.position.x < -(Tuning.spikeWidth + 10) else { return false }
            $0.node.removeFromParent(); return true
        }
        coins.removeAll {
            guard $0.node.position.x < -(Tuning.coinRadius + 10) else { return false }
            $0.node.removeFromParent(); return true
        }
    }

    // MARK: - Spawning

    private func trySpawn(dt: CGFloat, model: GameModel) {
        spawnTimer += Double(dt)
        guard spawnTimer >= model.spawnInterval else { return }
        spawnTimer = 0
        spawnPattern(model: model)
    }

    private func spawnPattern(model: GameModel) {
        let spawnX = size.width + Tuning.spikeWidth / 2 + 8

        if Double.random(in: 0..<1) < model.pinchProbability {
            spawnPinch(atX: spawnX)
        } else {
            spawnSingleSpike(atX: spawnX, isFloor: Bool.random())
        }

        if Double.random(in: 0..<1) < Tuning.coinSpawnChance {
            let coinX = spawnX + Tuning.spikeWidth / 2 + CGFloat.random(in: 55...140)
            spawnCoin(atX: coinX, isFloor: Bool.random())
        }
    }

    private func spawnSingleSpike(atX x: CGFloat, isFloor: Bool) {
        let node = makeSpikeNode(isFloor: isFloor, height: Tuning.spikeHeight)
        node.position = spikeBasePosition(x: x, isFloor: isFloor)
        addChild(node)
        spikes.append(SpikeData(node: node, isFloor: isFloor, visualHeight: Tuning.spikeHeight))
    }

    private func spawnPinch(atX x: CGFloat) {
        let corridorH = size.height - 2 * Tuning.surfaceThickness
        let eachH = max((corridorH - Tuning.pinchGapTarget) / 2, 20)

        for isFloor in [true, false] {
            let node = makeSpikeNode(isFloor: isFloor, height: eachH)
            node.position = spikeBasePosition(x: x, isFloor: isFloor)
            addChild(node)
            spikes.append(SpikeData(node: node, isFloor: isFloor, visualHeight: eachH))
        }
    }

    private func spikeBasePosition(x: CGFloat, isFloor: Bool) -> CGPoint {
        let sT = Tuning.surfaceThickness
        return CGPoint(x: x, y: isFloor ? sT : size.height - sT)
    }

    private func makeSpikeNode(isFloor: Bool, height: CGFloat) -> SKShapeNode {
        let hw   = Tuning.spikeWidth / 2
        let tipY = isFloor ? height : -height

        let path = CGMutablePath()
        path.move(to: CGPoint(x: -hw, y: 0))
        path.addLine(to: CGPoint(x: hw, y: 0))
        path.addLine(to: CGPoint(x: 0, y: tipY))
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        node.fillColor   = SKColor(red: 1.0, green: 0.28, blue: 0.16, alpha: 1.0)
        node.strokeColor = SKColor(red: 1.0, green: 0.58, blue: 0.30, alpha: 0.90)
        node.lineWidth = 1.5
        return node
    }

    private func spawnCoin(atX x: CGFloat, isFloor: Bool) {
        let sT = Tuning.surfaceThickness
        let y  = isFloor
            ? sT + Tuning.coinSurfaceOffset
            : size.height - sT - Tuning.coinSurfaceOffset

        let node = SKShapeNode(circleOfRadius: Tuning.coinRadius)
        node.fillColor   = SKColor(red: 1.0, green: 0.88, blue: 0.10, alpha: 1.0)
        node.strokeColor = SKColor(red: 1.0, green: 0.96, blue: 0.50, alpha: 0.90)
        node.lineWidth = 1
        node.position = CGPoint(x: x, y: y)
        addChild(node)
        coins.append(CoinData(node: node))
    }

    // MARK: - Collision detection (manual AABB)

    private func detectCollisions(model: GameModel) {
        let px = playerNode.position.x
        let py = playerNode.position.y
        let pr = Tuning.playerRadius - Tuning.playerHitShrink

        let pLeft = px - pr, pRight = px + pr
        let pBottom = py - pr, pTop = py + pr

        for spike in spikes {
            let hitH  = spike.visualHeight * Tuning.spikeHitFraction
            let hitHW = Tuning.spikeWidth  * Tuning.spikeHitFraction / 2
            let sX    = spike.node.position.x
            let sT    = Tuning.surfaceThickness

            let sLeft  = sX - hitHW, sRight = sX + hitHW
            let sBottom: CGFloat, sTop: CGFloat

            if spike.isFloor {
                sBottom = sT;          sTop = sT + hitH
            } else {
                sTop = size.height - sT; sBottom = sTop - hitH
            }

            if pRight > sLeft && pLeft < sRight && pTop > sBottom && pBottom < sTop {
                triggerDeath(model: model)
                return
            }
        }

        let pickupR2 = (pr + Tuning.coinRadius + 2) * (pr + Tuning.coinRadius + 2)
        for i in coins.indices where !coins[i].collected {
            let cn = coins[i].node
            let dx = cn.position.x - px
            let dy = cn.position.y - py
            if dx*dx + dy*dy < pickupR2 {
                let pos = cn.position
                coins[i].collected = true
                cn.removeFromParent()
                model.collectCoin()
                spawnCoinParticles(at: pos)
                if SettingsManager.shared.hapticsEnabled { impactLight.impactOccurred() }
                SoundManager.shared.playCoin()
            }
        }
    }

    // MARK: - Death

    private func triggerDeath(model: GameModel) {
        isRunActive = false
        model.die()
        playDeathFlash()
        spawnDeathParticles(at: playerNode.position)
        shakeCamera()
        if SettingsManager.shared.hapticsEnabled { impactHeavy.impactOccurred() }
        SoundManager.shared.playDeath()
    }

    private func playDeathFlash() {
        let flash = SKAction.sequence([
            .colorize(with: .red, colorBlendFactor: 1, duration: 0.07),
            .colorize(withColorBlendFactor: 0, duration: 0.07)
        ])
        playerNode.run(.repeat(flash, count: 3))
    }

    // MARK: - Camera shake

    private func shakeCamera() {
        let cx = size.width / 2, cy = size.height / 2
        let d = Tuning.shakeAmplitude

        gameCamera.removeAction(forKey: "shake")
        gameCamera.run(.sequence([
            .moveBy(x:  d,      y:  d * 0.5, duration: 0.03),
            .moveBy(x: -d * 2,  y: -d,       duration: 0.05),
            .moveBy(x:  d * 1.5,y:  d * 0.7, duration: 0.04),
            .moveBy(x: -d * 0.5,y: -d * 0.3, duration: 0.03),
            .move(to: CGPoint(x: cx, y: cy),  duration: 0.02)
        ]), withKey: "shake")
    }

    // MARK: - Particle bursts

    private func spawnDeathParticles(at pos: CGPoint) {
        guard !deathTextures.isEmpty else { return }

        for _ in 0..<Tuning.deathParticleCount {
            let tex = deathTextures.randomElement()!
            let p   = SKSpriteNode(texture: tex)
            p.position = pos
            p.zPosition = 10

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: Tuning.deathParticleMinSpeed...Tuning.deathParticleMaxSpeed)

            addChild(p)
            p.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * speed, y: sin(angle) * speed,
                            duration: Tuning.deathParticleLife),
                    .fadeOut(withDuration: Tuning.deathParticleLife),
                    .scale(to: 0.2, duration: Tuning.deathParticleLife)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnCoinParticles(at pos: CGPoint) {
        guard let tex = coinTexture else { return }

        for _ in 0..<Tuning.coinParticleCount {
            let p = SKSpriteNode(texture: tex)
            p.position = pos
            p.zPosition = 5

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: Tuning.coinParticleMinSpeed...Tuning.coinParticleMaxSpeed)

            addChild(p)
            p.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * speed, y: sin(angle) * speed,
                            duration: Tuning.coinParticleLife),
                    .fadeOut(withDuration: Tuning.coinParticleLife),
                    .scale(to: 0.3, duration: Tuning.coinParticleLife)
                ]),
                .removeFromParent()
            ]))
        }
    }
}
