import AppKit
import Combine
import Foundation

@MainActor
final class GroupsStore: ObservableObject {
    @Published private(set) var groups: [AppGroup] = []
    @Published var activeGroupID: AppGroup.ID?

    private let fileURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("cmdtab", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("groups.json")
    }()

    func load() {
        let loaded: [AppGroup]
        let needsSave: Bool
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([AppGroup].self, from: data),
           !decoded.isEmpty {
            var migrated = decoded
            for i in migrated.indices where migrated[i].name == "All" {
                migrated[i].isAllGroup = true
            }
            if !migrated.contains(where: { $0.isAllGroup }) {
                migrated.insert(AppGroup(name: "All", entries: [], isAllGroup: true), at: 0)
            }
            var seenAll = false
            migrated.removeAll { g in
                guard g.isAllGroup else { return false }
                defer { seenAll = true }
                return seenAll
            }
            if let allIdx = migrated.firstIndex(where: { $0.isAllGroup }), allIdx != 0 {
                let allGroup = migrated.remove(at: allIdx)
                migrated.insert(allGroup, at: 0)
            }
            migrated.removeAll { !$0.isAllGroup && $0.entries.isEmpty }
            loaded = migrated
            needsSave = migrated != decoded
        } else {
            loaded = Self.defaultGroups()
            needsSave = true
        }
        groups = loaded
        if needsSave { save() }
        // Restore last-active group if the saved id still exists.
        if let savedID = SwitcherSettings.lastActiveGroupID,
           loaded.contains(where: { $0.id == savedID }) {
            activeGroupID = savedID
        } else {
            activeGroupID = loaded.first?.id
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    func cycleActiveGroup() {
        guard !groups.isEmpty else { return }
        let currentIndex = groups.firstIndex(where: { $0.id == activeGroupID }) ?? -1
        let next = (currentIndex + 1) % groups.count
        activeGroupID = groups[next].id
    }

    var activeGroup: AppGroup? {
        groups.first(where: { $0.id == activeGroupID })
    }

    /// Append a bundle id to a target group. Returns true if it was
    /// actually added (false if the group is "All" or already
    /// contains it). Persists on success.
    @discardableResult
    func addBundleId(_ bundleIdentifier: String, to groupID: AppGroup.ID) -> Bool {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return false }
        guard !groups[idx].isAllGroup else { return false }
        if groups[idx].entries.contains(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return false
        }
        let displayName = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first?.localizedName ?? bundleIdentifier
        groups[idx].entries.append(AppEntry(bundleIdentifier: bundleIdentifier, displayName: displayName))
        save()
        return true
    }

    func removeBundleId(_ bundleIdentifier: String, from groupID: AppGroup.ID) {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        guard !groups[idx].isAllGroup else { return }
        groups[idx].entries.removeAll { $0.bundleIdentifier == bundleIdentifier }
        if groups[idx].entries.isEmpty {
            groups.remove(at: idx)
        }
        save()
    }

    func setActiveGroup(_ groupID: AppGroup.ID) {
        activeGroupID = groupID
        SwitcherSettings.lastActiveGroupID = groupID
    }

    @discardableResult
    func createGroup(from bundleId1: String, and bundleId2: String) -> AppGroup {
        let name1 = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId1)
            .first?.localizedName ?? bundleId1
        let name2 = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId2)
            .first?.localizedName ?? bundleId2
        let entry1 = AppEntry(bundleIdentifier: bundleId1, displayName: name1)
        let entry2 = AppEntry(bundleIdentifier: bundleId2, displayName: name2)
        let group = AppGroup(name: nextFolderName(), entries: [entry1, entry2])
        groups.append(group)
        save()
        return group
    }

    private func nextFolderName() -> String {
        let existing = Set(groups.map(\.name))
        if !existing.contains("Folder") { return "Folder" }
        var i = 2
        while existing.contains("Folder \(i)") { i += 1 }
        return "Folder \(i)"
    }

    private static func defaultGroups() -> [AppGroup] {
        [
            AppGroup(name: "All", entries: [], isAllGroup: true)
        ]
    }
}
