import Foundation

/// User-tweakable runtime settings backed by UserDefaults. Coordinator
/// reads them imperatively; the SwiftUI Settings view edits them via
/// `@AppStorage` against the same keys.
enum SwitcherSettings {
    enum Key: String {
        case activateOnRelease
        case lastActiveGroupID
    }

    static var lastActiveGroupID: UUID? {
        get {
            guard let s = UserDefaults.standard.string(forKey: Key.lastActiveGroupID.rawValue) else { return nil }
            return UUID(uuidString: s)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: Key.lastActiveGroupID.rawValue)
        }
    }

    /// When true (default): pressing the hotkey opens the switcher; the
    /// selection is committed when the modifier (Option) is released —
    /// classic Cmd+Tab behaviour. When false: hotkey is press-to-toggle,
    /// commit only via Enter or click.
    static var activateOnRelease: Bool {
        get { UserDefaults.standard.object(forKey: Key.activateOnRelease.rawValue) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Key.activateOnRelease.rawValue) }
    }
}
