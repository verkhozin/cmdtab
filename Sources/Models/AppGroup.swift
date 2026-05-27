import Foundation

struct AppGroup: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var entries: [AppEntry]
    /// True for the special pinned "All" pseudo-group: ignores
    /// entries, shows every running app, and doesn't accept drops.
    /// Defaults to false so user-created groups stay normal.
    var isAllGroup: Bool

    init(id: UUID = UUID(), name: String, entries: [AppEntry] = [], isAllGroup: Bool = false) {
        self.id = id
        self.name = name
        self.entries = entries
        self.isAllGroup = isAllGroup
    }

    enum CodingKeys: String, CodingKey { case id, name, entries, isAllGroup }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        entries = try c.decode([AppEntry].self, forKey: .entries)
        // Tolerant default keeps old groups.json files compatible.
        isAllGroup = try c.decodeIfPresent(Bool.self, forKey: .isAllGroup) ?? false
    }
}
