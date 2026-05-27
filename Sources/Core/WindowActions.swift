import AppKit
import ApplicationServices

/// Quick actions invokable from the switcher overlay.
///
/// `close` requires AX (operates on the specific window). `hide` and
/// `quit` operate on the whole `NSRunningApplication` and work even
/// without Accessibility — useful in the app-mode fallback.
enum WindowAction {
    case close, hide, quit
}

@MainActor
enum WindowActions {
    private static let actionClose = "AXClose" as CFString

    static func perform(_ action: WindowAction, on entry: WindowEntry) {
        switch action {
        case .close: close(entry)
        case .hide:  hide(entry)
        case .quit:  quit(entry)
        }
    }

    private static func close(_ entry: WindowEntry) {
        guard let element = entry.axElement else { return } // no-op in app-mode
        // `AXClose` is the canonical window-close action; it routes
        // through the app's standard close path so unsaved-change
        // dialogs still fire — exactly what users expect from ⌘W.
        AXUIElementPerformAction(element, actionClose)
    }

    private static func hide(_ entry: WindowEntry) {
        runningApp(for: entry)?.hide()
    }

    private static func quit(_ entry: WindowEntry) {
        runningApp(for: entry)?.terminate()
    }

    private static func runningApp(for entry: WindowEntry) -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications
        if let byPID = apps.first(where: { $0.processIdentifier == entry.pid }) {
            return byPID
        }
        return apps.first(where: { $0.bundleIdentifier == entry.bundleId })
    }
}
