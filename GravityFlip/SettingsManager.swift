import Foundation

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private enum Key {
        static let sound   = "gf_soundEnabled"
        static let haptics = "gf_hapticsEnabled"
    }

    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: Key.sound) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Key.haptics) }
    }

    private init() {
        let ud = UserDefaults.standard
        soundEnabled   = ud.object(forKey: Key.sound)   as? Bool ?? true
        hapticsEnabled = ud.object(forKey: Key.haptics) as? Bool ?? true
    }
}
