import AppKit

/// Brings a target app — or a specific window of it — to the foreground.
@MainActor
enum AppActivator {
    static func activate(bundleIdentifier: String) {
        let workspace = NSWorkspace.shared
        if let running = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            running.activate()
            return
        }
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        workspace.openApplication(at: url, configuration: config) { _, _ in }
    }

    /// Per-window activation: brings the owning app forward, then
    /// raises the specific AX window. Falls back to whole-app
    /// activation when the entry has no AX element (no permission).
    static func activate(window: WindowEntry) {
        if let element = window.axElement,
           let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == window.pid }) {
            runningApp.activate()
            WindowsLister.raise(window: element)
        } else {
            activate(bundleIdentifier: window.bundleId)
        }
    }
}
