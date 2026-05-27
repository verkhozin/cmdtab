import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let groupsStore = GroupsStore()
    private(set) var hotkeyManager: HotkeyManager!
    private(set) var switcherCoordinator: SwitcherCoordinator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        groupsStore.load()
        switcherCoordinator = SwitcherCoordinator(groupsStore: groupsStore)
        hotkeyManager = HotkeyManager { [weak self] in
            self?.switcherCoordinator.toggle()
        }
        hotkeyManager.registerDefault()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }
}
