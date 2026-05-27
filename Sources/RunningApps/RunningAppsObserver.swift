import AppKit
import Combine

/// Snapshots the set of currently running, user-visible (regular activation
/// policy) applications and emits updates whenever apps launch/terminate.
@MainActor
final class RunningAppsObserver: ObservableObject {
    @Published private(set) var apps: [AppEntry] = []

    /// Tokens are stored only to keep them alive for the object's lifetime.
    /// We deliberately don't tear them down in deinit — `RunningAppsObserver`
    /// is owned by the long-lived `SwitcherCoordinator`, and main-actor
    /// teardown from a nonisolated deinit isn't worth the dance.
    private var observers: [NSObjectProtocol] = []

    init() {
        refresh()
        let nc = NSWorkspace.shared.notificationCenter
        observers.append(nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                                        object: nil,
                                        queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        observers.append(nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                        object: nil,
                                        queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
    }

    func refresh() {
        apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(AppEntry.init(runningApp:))
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }
}
