import SwiftUI

@main
struct CmdtabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.groupsStore)
        }

        MenuBarExtra("cmdtab", systemImage: "command") {
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")
            Divider()
            Button("Quit cmdtab") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
