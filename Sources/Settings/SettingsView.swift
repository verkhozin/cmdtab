import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var groupsStore: GroupsStore

    var body: some View {
        TabView {
            GroupsTab().tabItem { Label("Groups", systemImage: "square.grid.2x2") }
            HotkeyTab().tabItem { Label("Hotkey", systemImage: "command") }
            AppearanceTab().tabItem { Label("Appearance", systemImage: "paintbrush") }
        }
        .frame(width: 560, height: 420)
    }
}

private struct GroupsTab: View {
    @EnvironmentObject private var groupsStore: GroupsStore

    var body: some View {
        List {
            ForEach(groupsStore.groups) { group in
                Section(group.name) {
                    if group.entries.isEmpty {
                        Text("No apps yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(group.entries) { entry in
                            Text(entry.displayName)
                        }
                    }
                }
            }
        }
    }
}

private struct HotkeyTab: View {
    @AppStorage(SwitcherSettings.Key.activateOnRelease.rawValue) private var activateOnRelease: Bool = true

    var body: some View {
        Form {
            Section {
                LabeledContent("Toggle switcher", value: "⌥ + Y")
                Text("Custom hotkeys are coming. Y is a placeholder unused-key for testing.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Activation") {
                Toggle("Activate on hotkey release", isOn: $activateOnRelease)
                Text(activateOnRelease
                     ? "Press ⌥+Y to open. Hold ⌥, press Y again to advance. Release ⌥ to switch — like the system Cmd+Tab."
                     : "Press ⌥+Y to toggle. Press Enter or click to switch.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AppearanceTab: View {
    var body: some View {
        Form {
            Text("Icon size, blur, position — TODO.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
