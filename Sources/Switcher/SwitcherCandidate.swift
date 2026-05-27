import Foundation

/// Sum type for what a switcher cell can represent.
///
/// In `All` mode the candidate list is a mix of `folder` (one per
/// user-defined group) followed by `window` for the ungrouped
/// running windows. In a user-group mode the list is purely
/// `window` cases. The coordinator branches on this when the user
/// commits: folder → drill in, window → activate.
enum SwitcherCandidate: Identifiable, Hashable {
    case folder(AppGroup)
    case window(WindowEntry)

    var id: String {
        switch self {
        case .folder(let g): return "folder:\(g.id.uuidString)"
        case .window(let w): return "window:\(w.id)"
        }
    }

    var asWindow: WindowEntry? {
        if case .window(let w) = self { return w }
        return nil
    }

    var asFolder: AppGroup? {
        if case .folder(let g) = self { return g }
        return nil
    }

    /// Bundle id used by the divider logic to detect app boundaries
    /// between adjacent window cells. Folders have no bundle id, so
    /// no divider is drawn next to them.
    var bundleIdForBoundary: String? {
        switch self {
        case .folder: return nil
        case .window(let w): return w.bundleId
        }
    }
}
