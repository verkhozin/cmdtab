import Combine
import Foundation

enum ContentPhase: Equatable {
    case visible, zoomOut, zoomIn
}

@MainActor
final class SwitcherViewModel: ObservableObject {
    @Published private(set) var candidates: [SwitcherCandidate] = []
    @Published var selectedIndex: Int = 0
    @Published var columnsPerRow: Int = 1
    @Published private(set) var perWindowMode: Bool = false
    @Published var contentPhase: ContentPhase = .visible

    private let groupsStore: GroupsStore

    init(groupsStore: GroupsStore) {
        self.groupsStore = groupsStore
    }

    func refreshCandidates() {
        let group = groupsStore.activeGroup
        let granted = AccessibilityPermissions.isGranted()
        perWindowMode = granted

        if let group, group.isAllGroup {
            candidates = buildAllModeCandidates(granted: granted)
        } else {
            candidates = buildGroupModeCandidates(group: group, granted: granted)
        }
        // Clamp the prior selection into the new bounds so callers
        // (e.g. after a window close) keep the user's place instead
        // of snapping back to the first cell.
        selectedIndex = candidates.isEmpty ? 0 : min(max(selectedIndex, 0), candidates.count - 1)
    }

    /// In "All" mode we present folders for user groups followed by
    /// running windows that don't belong to any user group. Folders
    /// always come first so the user can drill in quickly.
    private func buildAllModeCandidates(granted: Bool) -> [SwitcherCandidate] {
        let userGroups = groupsStore.groups.filter { !$0.isAllGroup }
        let groupedBundleIds = Set(userGroups.flatMap { $0.entries.map(\.bundleIdentifier) })

        let allWindows: [WindowEntry] = granted
            ? WindowsLister.listWindows(filteringBy: nil)
            : WindowsLister.listAppsAsWindows(filteringBy: nil)
        let ungrouped = allWindows.filter { !groupedBundleIds.contains($0.bundleId) }

        var result: [SwitcherCandidate] = userGroups.map { .folder($0) }
        result.append(contentsOf: ungrouped.map { .window($0) })
        return result
    }

    private func buildGroupModeCandidates(group: AppGroup?, granted: Bool) -> [SwitcherCandidate] {
        let filter: Set<String>?
        if let group {
            filter = Set(group.entries.map(\.bundleIdentifier))
        } else {
            filter = nil
        }
        let windows = granted
            ? WindowsLister.listWindows(filteringBy: filter)
            : WindowsLister.listAppsAsWindows(filteringBy: filter)
        return windows.map { .window($0) }
    }

    func selectNext() {
        guard !candidates.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % candidates.count
    }

    func selectPrevious() {
        guard !candidates.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + candidates.count) % candidates.count
    }

    func selectDown() {
        guard !candidates.isEmpty else { return }
        let target = selectedIndex + max(1, columnsPerRow)
        selectedIndex = min(candidates.count - 1, target)
    }

    func selectUp() {
        guard !candidates.isEmpty else { return }
        let target = selectedIndex - max(1, columnsPerRow)
        selectedIndex = max(0, target)
    }

    func cycleGroup() {
        // State-only: the coordinator owns the refresh+relayout
        // sequence so the view's column count stays in sync.
        groupsStore.cycleActiveGroup()
    }

    var selectedCandidate: SwitcherCandidate? {
        guard candidates.indices.contains(selectedIndex) else { return nil }
        return candidates[selectedIndex]
    }
}
