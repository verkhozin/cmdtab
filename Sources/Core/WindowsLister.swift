import AppKit
import ApplicationServices

/// Enumerates the open windows of running apps via the AX API.
///
/// AX constants are declared as C `var` globals in the headers, which
/// Swift treats as non-Sendable shared state under strict concurrency.
/// We use the underlying string values directly to avoid that — they
/// are stable Apple-public API ("AXWindows", "AXTitle", "AXRaise", …).
@MainActor
enum WindowsLister {
    private static let attrWindows = "AXWindows" as CFString
    private static let attrTitle = "AXTitle" as CFString
    private static let attrMinimized = "AXMinimized" as CFString
    private static let actionRaise = "AXRaise" as CFString

    /// One `WindowEntry` per AX window across all matching running apps.
    /// Filters by `bundleIds` if provided (used for active-group filter);
    /// pass nil to list everything.
    static func listWindows(filteringBy bundleIds: Set<String>?) -> [WindowEntry] {
        regularApps(filteringBy: bundleIds).flatMap { app, _ in windows(of: app) }
    }

    /// Same shape, but one entry per APP — used as the fallback when
    /// the user hasn't granted Accessibility access.
    static func listAppsAsWindows(filteringBy bundleIds: Set<String>?) -> [WindowEntry] {
        regularApps(filteringBy: bundleIds)
            .map { app, bid in
                let name = app.localizedName ?? bid
                return WindowEntry(
                    id: bid,
                    title: name,
                    appName: name,
                    bundleId: bid,
                    pid: app.processIdentifier,
                    axElement: nil
                )
            }
            .sorted { $0.appName.localizedCompare($1.appName) == .orderedAscending }
    }

    /// Running apps with `.regular` activation policy and a bundle id,
    /// optionally restricted to `bundleIds`. Shared by the AX-window
    /// and app-mode listers.
    private static func regularApps(filteringBy bundleIds: Set<String>?) -> [(NSRunningApplication, String)] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular,
                  let bid = app.bundleIdentifier,
                  bundleIds?.contains(bid) ?? true
            else { return nil }
            return (app, bid)
        }
    }

    private static func windows(of runningApp: NSRunningApplication) -> [WindowEntry] {
        let pid = runningApp.processIdentifier
        let appName = runningApp.localizedName ?? runningApp.bundleIdentifier ?? "Unknown"
        let bundleId = runningApp.bundleIdentifier ?? ""

        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(appElement, attrWindows, &windowsRef)
        guard status == .success, let axWindows = windowsRef as? [AXUIElement] else { return [] }

        var entries: [WindowEntry] = []
        for (idx, window) in axWindows.enumerated() {
            // Skip minimised windows — the user expects raise to bring
            // a usable window forward, not a Dock-icon ghost.
            if isMinimized(window) { continue }
            let title = title(of: window) ?? appName
            let id = "\(pid):\(idx):\(title)"
            entries.append(WindowEntry(
                id: id,
                title: title,
                appName: appName,
                bundleId: bundleId,
                pid: pid,
                axElement: window
            ))
        }
        return entries
    }

    private static func title(of window: AXUIElement) -> String? {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(window, attrTitle, &ref)
        guard let s = ref as? String, !s.isEmpty else { return nil }
        return s
    }

    private static func isMinimized(_ window: AXUIElement) -> Bool {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(window, attrMinimized, &ref)
        return (ref as? Bool) == true
    }

    static func raise(window: AXUIElement) {
        AXUIElementPerformAction(window, actionRaise)
    }
}
