import XCTest
@testable import cmdtab

@MainActor
final class GroupsStoreTests: XCTestCase {
    func testCycleActiveGroupWrapsAround() {
        let store = GroupsStore()
        store.load()
        guard store.groups.count >= 2 else {
            XCTFail("Expected default groups to be seeded")
            return
        }
        let first = store.activeGroupID
        store.cycleActiveGroup()
        XCTAssertNotEqual(store.activeGroupID, first)
        for _ in 0..<store.groups.count - 1 { store.cycleActiveGroup() }
        XCTAssertEqual(store.activeGroupID, first)
    }
}
