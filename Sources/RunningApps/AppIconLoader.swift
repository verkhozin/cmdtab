import AppKit

/// Caches NSImage icons for apps. NSWorkspace.icon(forFile:) is the
/// canonical way; it picks the best representation for the current
/// scale factor automatically.
@MainActor
final class AppIconLoader {
    static let shared = AppIconLoader()

    private var cache: [String: NSImage] = [:]

    private init() {}

    func icon(for bundleIdentifier: String) -> NSImage? {
        if let cached = cache[bundleIdentifier] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 512, height: 512)
        cache[bundleIdentifier] = icon
        return icon
    }
}
