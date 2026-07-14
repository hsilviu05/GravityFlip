import GameKit

// All Game Center interactions live here. Every method is safe to call when
// GC is unavailable (offline, declined, simulator) — it silently no-ops.
final class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()

    // Must match the leaderboard ID created in App Store Connect.
    static let leaderboardID = "com.gravityflip.bestdistance"

    @Published private(set) var isAuthenticated = false

    private override init() { super.init() }

    // MARK: - Auth

    // Call once at launch. The system shows its sign-in sheet only on
    // first-ever use; subsequent calls are instant and silent.
    func authenticateQuietly() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            if let vc = viewController {
                // First-time login — present the Game Center sign-in sheet.
                self?.presentFromRoot(vc)
            } else if GKLocalPlayer.local.isAuthenticated {
                DispatchQueue.main.async { self?.isAuthenticated = true }
            }
            // Offline / declined / simulator: falls through silently.
        }
    }

    // MARK: - Score

    func submitScore(_ score: Int) {
        guard isAuthenticated, score > 0 else { return }
        GKLeaderboard.submitScore(
            score, context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [Self.leaderboardID]
        ) { _ in }   // errors (leaderboard not yet configured) are silently ignored
    }

    // MARK: - Leaderboard UI

    func showLeaderboard() {
        guard isAuthenticated else { return }
        guard let root = rootViewController() else { return }

        let gcVC = GKGameCenterViewController(
            leaderboardID: Self.leaderboardID,
            playerScope: .global,
            timeScope: .allTime
        )
        gcVC.gameCenterDelegate = self
        root.present(gcVC, animated: true)
    }

    // MARK: - Helpers

    private func presentFromRoot(_ vc: UIViewController) {
        rootViewController()?.present(vc, animated: true)
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gcVC: GKGameCenterViewController) {
        gcVC.dismiss(animated: true)
    }
}
