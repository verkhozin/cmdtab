import AppKit
import Foundation

struct AppEntry: Identifiable, Hashable, Codable, Sendable {
    let bundleIdentifier: String
    var displayName: String

    var id: String { bundleIdentifier }

    init(bundleIdentifier: String, displayName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }

    init?(runningApp: NSRunningApplication) {
        guard let bid = runningApp.bundleIdentifier else { return nil }
        self.bundleIdentifier = bid
        self.displayName = runningApp.localizedName ?? bid
    }
}
