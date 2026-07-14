import SwiftUI
import SpriteKit

// Owns the scene and model for the lifetime of the app.
private final class GameCoordinator: ObservableObject {
    let model = GameModel()
    let scene: GameScene

    init() {
        scene = GameScene(size: CGSize(width: 393, height: 852))
        scene.scaleMode = .resizeFill
        scene.gameModel = model
    }

    // MARK: - Run control

    func startRun() {
        AdManager.shared.recordRunStarted()
        guard let vc = rootViewController() else { _startRun(); return }
        AdManager.shared.tryShowInterstitial(from: vc) { [weak self] in
            self?._startRun()
        }
    }

    private func _startRun() {
        model.startRun()
        scene.resetForNewRun()
    }

    func returnToMenu() {
        guard let vc = rootViewController() else { _returnToMenu(); return }
        AdManager.shared.tryShowInterstitial(from: vc) { [weak self] in
            self?._returnToMenu()
        }
    }

    private func _returnToMenu() {
        model.returnToMenu()
        scene.prepareForMenu()
    }

    // MARK: - Rewarded flows

    func watchAdToContinue() {
        guard let vc = rootViewController() else { return }
        AdManager.shared.showRewarded(from: vc) { [weak self] earned in
            DispatchQueue.main.async {
                guard earned, let self else { return }
                self.model.continueRun()
                self.scene.resurrectPlayer()
            }
        }
    }

    func watchAdToDoubleCoins() {
        guard let vc = rootViewController() else { return }
        AdManager.shared.showRewarded(from: vc) { [weak self] earned in
            DispatchQueue.main.async {
                if earned { self?.model.doubleCoins() }
            }
        }
    }

    // MARK: - Helpers

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}

// MARK: - Root view

struct ContentView: View {
    @StateObject private var gc     = GameCoordinator()
    @ObservedObject private var gcMgr  = GameCenterManager.shared
    @ObservedObject private var adMgr  = AdManager.shared
    @State private var showSettings = false

    var body: some View {
        ZStack {
            SpriteView(scene: gc.scene)
                .ignoresSafeArea()

            if gc.model.phase == .playing {
                PlayHUD(model: gc.model)
            }

            if gc.model.phase == .menu {
                MenuOverlay(
                    model: gc.model,
                    gcMgr: gcMgr,
                    onStart:       gc.startRun,
                    onLeaderboard: GameCenterManager.shared.showLeaderboard,
                    onSettings:    { showSettings = true }
                )
            }

            if gc.model.phase == .dead {
                GameOverOverlay(
                    model: gc.model,
                    gcMgr: gcMgr,
                    adMgr: adMgr,
                    onRestart:        gc.startRun,
                    onMenu:           gc.returnToMenu,
                    onLeaderboard:    GameCenterManager.shared.showLeaderboard,
                    onContinue:       gc.watchAdToContinue,
                    onDoubleCoins:    gc.watchAdToDoubleCoins
                )
            }
        }
        .statusBar(hidden: true)
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .onAppear { GameCenterManager.shared.authenticateQuietly() }
    }
}

// MARK: - Play HUD

private struct PlayHUD: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(model.score))m")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3)

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(red: 1, green: 0.88, blue: 0.10))
                        .frame(width: 13, height: 13)
                    Text("\(model.coins)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 1, green: 0.90, blue: 0.30))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)

            Spacer()
        }
    }
}

// MARK: - Menu

private struct MenuOverlay: View {
    @ObservedObject var model: GameModel
    @ObservedObject var gcMgr: GameCenterManager
    let onStart:       () -> Void
    let onLeaderboard: () -> Void
    let onSettings:    () -> Void

    @State private var breathe = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.50).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Title
                VStack(spacing: 2) {
                    Text("GRAVITY")
                        .font(.system(size: 58, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.95, blue: 1.0))
                    Text("FLIP")
                        .font(.system(size: 78, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .scaleEffect(breathe ? 1.025 : 0.975)
                .animation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true),
                           value: breathe)

                // Stats (only after the player's first run)
                if model.highScore > 0 {
                    VStack(spacing: 4) {
                        Text("BEST  \(Int(model.highScore))m")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.60))
                        if model.totalCoins > 0 {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color(red: 1, green: 0.88, blue: 0.10))
                                    .frame(width: 9, height: 9)
                                Text("\(model.totalCoins) coins total")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(Color(red: 1, green: 0.90, blue: 0.30)
                                        .opacity(0.75))
                            }
                        }
                    }
                    .padding(.top, 14)
                }

                Spacer().frame(height: 36)

                // Instructions
                VStack(spacing: 9) {
                    instructionRow(icon: "hand.tap.fill",
                                   text: "TAP TO FLIP GRAVITY")
                    instructionRow(icon: "bolt.trianglebadge.exclamationmark.fill",
                                   text: "AVOID THE SPIKES")
                    instructionRow(icon: "circle.fill",
                                   text: "COLLECT COINS")
                }

                Spacer().frame(height: 46)

                // Action row:  ⚙  ── PLAY ──  🏆
                HStack(spacing: 22) {
                    circleIconButton(systemImage: "gearshape.fill",
                                     action: onSettings)

                    Button(action: onStart) {
                        Text("PLAY")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(width: 148, height: 52)
                            .background(Capsule()
                                .fill(Color(red: 0.25, green: 0.95, blue: 1.0)))
                    }
                    .scaleEffect(breathe ? 0.96 : 1.04)
                    .animation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true),
                               value: breathe)

                    circleIconButton(systemImage: "trophy.fill",
                                     action: gcMgr.isAuthenticated ? onLeaderboard : {})
                        .opacity(gcMgr.isAuthenticated ? 1 : 0.28)
                }

                Spacer()

                // Adaptive banner — collapses when no fill
                AdBannerView()
            }
        }
        .onAppear { breathe = true }
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.25, green: 0.95, blue: 1.0))
                .frame(width: 22)
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
                .tracking(1.5)
        }
    }

    private func circleIconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 48, height: 48)
                .background(Circle().fill(.white.opacity(0.10)))
        }
    }
}

// MARK: - Game Over

private struct GameOverOverlay: View {
    @ObservedObject var model: GameModel
    @ObservedObject var gcMgr: GameCenterManager
    @ObservedObject var adMgr: AdManager
    let onRestart:     () -> Void
    let onMenu:        () -> Void
    let onLeaderboard: () -> Void
    let onContinue:    () -> Void
    let onDoubleCoins: () -> Void

    @State private var appeared = false

    // Whether the rewarded "Continue" option should be shown
    private var canOfferContinue: Bool {
        !model.alreadyContinued && adMgr.isRewardedReady
    }

    // Whether the rewarded "Double Coins" option should be shown
    private var canOfferDoubleCoins: Bool {
        !model.coinsDoubled && adMgr.isRewardedReady
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    Text("GAME OVER")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    // Score card
                    VStack(spacing: 6) {
                        Text("DISTANCE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                            .tracking(3)

                        Text("\(Int(model.score))m")
                            .font(.system(size: 60, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 0.25, green: 0.95, blue: 1.0))

                        if model.isNewBest {
                            Text("NEW BEST!")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.yellow)
                                .tracking(2)
                        } else if model.highScore > 0 {
                            Text("BEST  \(Int(model.highScore))m")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.07)))

                    // Coins earned this run
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 1, green: 0.88, blue: 0.10))
                            .frame(width: 13, height: 13)
                        Text(model.coinsDoubled
                             ? "+\(model.coins) coins  ×2!"
                             : "+\(model.coins) coins")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(red: 1, green: 0.90, blue: 0.30))
                    }

                    // Rewarded ad row — appears only when ads are loaded
                    if canOfferContinue || canOfferDoubleCoins {
                        HStack(spacing: 12) {
                            if canOfferContinue {
                                rewardedButton(
                                    label: "CONTINUE",
                                    icon: "play.fill",
                                    action: onContinue
                                )
                            }
                            if canOfferDoubleCoins {
                                rewardedButton(
                                    label: "2× COINS",
                                    icon: "circle.fill",
                                    action: onDoubleCoins
                                )
                            }
                        }
                    }

                    // Primary: Play Again
                    Button(action: onRestart) {
                        Text("PLAY AGAIN")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Capsule()
                                .fill(Color(red: 0.25, green: 0.95, blue: 1.0)))
                    }

                    // Secondary: Leaderboard + Menu
                    HStack(spacing: 16) {
                        if gcMgr.isAuthenticated {
                            outlineButton(label: "LEADERBOARD",
                                          icon: "trophy.fill",
                                          action: onLeaderboard)
                        }
                        outlineButton(label: "MENU",
                                      icon: "house.fill",
                                      action: onMenu)
                    }
                }
                .padding(28)
                .scaleEffect(appeared ? 1 : 0.82)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(duration: 0.38), value: appeared)

                Spacer()

                // Adaptive banner — collapses when no fill
                AdBannerView()
            }
        }
        .onAppear {
            appeared = true
            AdManager.shared.notifyFirstGameOver()
        }
    }

    private func rewardedButton(label: String, icon: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "film")
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(0.8)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule()
                .fill(Color(red: 1, green: 0.88, blue: 0.10)))
        }
    }

    private func outlineButton(label: String, icon: String,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .strokeBorder(.white.opacity(0.20), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings sheet

private struct SettingsSheet: View {
    @ObservedObject private var settings  = SettingsManager.shared
    @ObservedObject private var storeMgr  = StoreManager.shared
    @Environment(\.dismiss) private var dismiss

    private let cyan = Color(red: 0.25, green: 0.95, blue: 1.0)

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.14).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("SETTINGS")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("DONE") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(cyan)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 22)

                Divider().background(.white.opacity(0.10))

                settingsRow(label: "SOUND EFFECTS",
                            icon: "speaker.wave.2.fill",
                            binding: $settings.soundEnabled)

                Divider().background(.white.opacity(0.10))

                settingsRow(label: "HAPTIC FEEDBACK",
                            icon: "hand.tap.fill",
                            binding: $settings.hapticsEnabled)

                Divider().background(.white.opacity(0.10))

                // Purchase section
                if storeMgr.adsRemoved {
                    purchasedRow()
                } else {
                    removeAdsRow()
                    Divider().background(.white.opacity(0.10))
                    restoreRow()
                }

                Divider().background(.white.opacity(0.10))
                Spacer()
            }
        }
        .presentationDetents([.fraction(storeMgr.adsRemoved ? 0.38 : 0.52)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Rows

    private func settingsRow(label: String, icon: String,
                              binding: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(cyan)
                .frame(width: 26)
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .tracking(1)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(cyan)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 17)
    }

    @ViewBuilder
    private func purchasedRow() -> some View {
        HStack(spacing: 14) {
            Image(systemName: "nosign")
                .font(.system(size: 16))
                .foregroundStyle(cyan)
                .frame(width: 26)
            Text("ADS REMOVED")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .tracking(1)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(cyan)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 17)
    }

    @ViewBuilder
    private func removeAdsRow() -> some View {
        let isBusy = storeMgr.purchaseStatus == .purchasing
        let isPending = storeMgr.purchaseStatus == .pending

        HStack(spacing: 14) {
            Image(systemName: "nosign")
                .font(.system(size: 16))
                .foregroundStyle(cyan)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("REMOVE ADS")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(1)
                if isPending {
                    Text("PENDING APPROVAL")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.yellow.opacity(0.80))
                        .tracking(1)
                }
            }
            Spacer()

            Button {
                Task { await storeMgr.buy() }
            } label: {
                Group {
                    if isBusy {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.black)
                            .scaleEffect(0.75)
                            .frame(width: 60, height: 26)
                    } else {
                        Text(storeMgr.product?.displayPrice ?? "$3.99")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                }
                .frame(minWidth: 60, minHeight: 26)
                .background(Capsule().fill(isBusy || isPending ? Color.gray : cyan))
            }
            .disabled(isBusy || isPending || storeMgr.product == nil)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 17)
    }

    @ViewBuilder
    private func restoreRow() -> some View {
        let isRestoring = storeMgr.purchaseStatus == .restoring

        Button {
            Task { await storeMgr.restore() }
        } label: {
            HStack {
                if isRestoring {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(cyan)
                        .scaleEffect(0.75)
                }
                Text(isRestoring ? "RESTORING..." : "RESTORE PURCHASES")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isRestoring ? .white.opacity(0.40) : cyan.opacity(0.75))
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .disabled(isRestoring)
    }
}
