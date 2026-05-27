import ApplicationServices
import Foundation

/// A switcher candidate. Replaces the previous app-only model.
///
/// In **window mode** (Accessibility granted): one entry per window per
/// running app — `axElement` points at the AX handle we use to raise it.
///
/// In **app-mode fallback** (no Accessibility): one entry per app,
/// `axElement` is nil, activation falls back to bundle-id launch.
struct WindowEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let appName: String
    let bundleId: String
    let pid: pid_t
    let axElement: AXUIElement?

    static func == (lhs: WindowEntry, rhs: WindowEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// True when the window's title is meaningfully different from the
    /// app name — drives whether we render a secondary "app name" line.
    var hasDistinctTitle: Bool { !title.isEmpty && title != appName }
}
