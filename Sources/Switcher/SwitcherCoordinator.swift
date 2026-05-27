import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Owns the borderless floating window that shows the switcher and
/// translates user input into selection / activation.
@MainActor
final class SwitcherCoordinator {
    private let groupsStore: GroupsStore
    private let viewModel: SwitcherViewModel
    private var window: SwitcherWindow?
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    /// We only ask once per process — system AX dialog is sticky
    /// enough; users find the toggle in System Settings on their own.
    private var promptedForAccessibility = false
    private var pendingGroupSwitch: AppGroup.ID?

    init(groupsStore: GroupsStore) {
        self.groupsStore = groupsStore
        self.viewModel = SwitcherViewModel(groupsStore: groupsStore)
    }

    /// Hotkey behaviour:
    /// - First press → open switcher, select first candidate.
    /// - Subsequent presses while open → advance selection (Cmd+Tab style).
    /// - If `activateOnRelease` is on (default) and Option is currently
    ///   held, install a flagsChanged watcher that commits when Option
    ///   is released — completing the Cmd+Tab metaphor.
    func toggle() {
        if window?.isVisible == true {
            viewModel.selectNext()
        } else {
            show()
        }
        if SwitcherSettings.activateOnRelease, NSEvent.modifierFlags.contains(.option) {
            installFlagsMonitor()
        }
    }

    private func show() {
        promptForAccessibilityIfNeeded()
        refreshAndRecomputeColumns()

        // Tear down any leftover monitors from a previous session
        // (close paths can early-return on folder drill-in, leaving
        // them attached). installKeyMonitor below re-adds clean ones.
        removeKeyMonitor()
        removeFlagsMonitor()

        let window = window ?? makeWindow()
        self.window = window

        positionAndDisplay(window)

        installKeyMonitor()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func close(activatingSelection: Bool) {
        if activatingSelection, let candidate = viewModel.selectedCandidate {
            switch candidate {
            case .folder(let group):
                switchContent(to: group.id, zoom: true)
                return
            case .window(let entry):
                AppActivator.activate(window: entry)
            }
        }
        removeKeyMonitor()
        removeFlagsMonitor()
        window?.orderOut(nil)
    }

    private func makeWindow() -> SwitcherWindow {
        let view = SwitcherView(
            viewModel: viewModel,
            groupsStore: groupsStore,
            onCommit: { [weak self] in self?.close(activatingSelection: true) },
            onCancel: { [weak self] in self?.close(activatingSelection: false) },
            onAction: { [weak self] index, action in
                guard let self else { return }
                self.viewModel.selectedIndex = index
                self.performAction(action)
            },
            onMouseTakeover: { [weak self] in
                // Mouse engaged → user is in deliberate mode. Releasing
                // Option must NOT auto-commit (they probably let go to
                // grab the mouse). Tear down the flags monitor.
                self?.removeFlagsMonitor()
            },
            onSelectGroup: { [weak self] groupID in
                self?.selectGroup(groupID)
            },
            onDropToGroup: { [weak self] bundleId, groupID in
                guard let self else { return false }
                let added = self.groupsStore.addBundleId(bundleId, to: groupID)
                if added {
                    self.refreshAndRecomputeColumns()
                    self.relayoutWindowAnimated()
                }
                return added
            },
            onCreateGroup: { [weak self] bundleId1, bundleId2 in
                guard let self else { return }
                self.groupsStore.createGroup(from: bundleId1, and: bundleId2)
                self.refreshAndRecomputeColumns()
                self.relayoutWindowAnimated()
            },
            onRemoveFromGroup: { [weak self] bundleId in
                guard let self, let groupID = self.groupsStore.activeGroupID else { return }
                self.groupsStore.removeBundleId(bundleId, from: groupID)
                if self.groupsStore.groups.contains(where: { $0.id == groupID }) {
                    self.refreshAndRecomputeColumns()
                    self.relayoutWindowAnimated()
                } else {
                    guard let allID = self.groupsStore.groups.first?.id else { return }
                    self.switchContent(to: allID)
                }
            }
        )
        return SwitcherWindow(rootView: view)
    }

    private func selectGroup(_ id: AppGroup.ID) {
        switchContent(to: id)
    }

    private func switchContent(to groupID: AppGroup.ID, zoom: Bool = false) {
        pendingGroupSwitch = groupID
        groupsStore.setActiveGroup(groupID)

        withAnimation(.spring(response: zoom ? 0.28 : 0.22, dampingFraction: zoom ? 0.86 : 0.9)) {
            viewModel.contentPhase = .zoomOut
        }

        let delay: Double = zoom ? 0.2 : 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.pendingGroupSwitch == groupID else { return }
            self.viewModel.refreshCandidates()
            self.viewModel.columnsPerRow = self.optimalColumns(for: self.viewModel.candidates.count)
            self.viewModel.contentPhase = .zoomIn
            self.relayoutWindowAnimated()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.pendingGroupSwitch == groupID else { return }
                withAnimation(.spring(response: zoom ? 0.38 : 0.3, dampingFraction: zoom ? 0.82 : 0.85)) {
                    self.viewModel.contentPhase = .visible
                }
                self.pendingGroupSwitch = nil
            }
        }
    }

    /// Pull fresh candidates from the store, then recompute how many
    /// cells fit per row based on the new count. Always paired so the
    /// grid never renders with a stale column count.
    private func refreshAndRecomputeColumns() {
        viewModel.refreshCandidates()
        viewModel.columnsPerRow = optimalColumns(for: viewModel.candidates.count)
    }

    private func relayoutWindow() {
        guard let window, window.isVisible else { return }
        positionAndDisplay(window)
    }

    private func relayoutWindowAnimated() {
        guard let window, window.isVisible else { return }
        window.contentView?.layoutSubtreeIfNeeded()
        let size = window.contentView?.fittingSize ?? window.frame.size
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.1
        )
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 1.0, 0.3, 1.0)
            ctx.allowsImplicitAnimation = true
            window.animator().setFrame(NSRect(origin: origin, size: size), display: true)
        }
    }

    /// Force a SwiftUI layout pass, measure the resulting fitting size,
    /// then center the window on the active screen (biased upward by
    /// 10% of screen height so the panel sits where the eye expects).
    ///
    /// The explicit `layoutSubtreeIfNeeded` is load-bearing: without it
    /// the panel measures its previous frame, gets positioned, and
    /// then resizes — which slides it off the right of the screen.
    private func positionAndDisplay(_ window: SwitcherWindow) {
        window.contentView?.layoutSubtreeIfNeeded()
        let size = window.contentView?.fittingSize ?? window.frame.size
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.1
        )
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func performAction(_ action: WindowAction) {
        // Quick actions only apply to windows. If the selection is a
        // folder, silently no-op — folder-level actions live in the
        // (future) folder context menu.
        guard let entry = viewModel.selectedCandidate?.asWindow else { return }
        WindowActions.perform(action, on: entry)
        // Give the OS a beat to update its window/app inventory before
        // we re-list. Without this, the closed window often still shows.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.viewModel.refreshCandidates()
            if self.viewModel.candidates.isEmpty {
                self.close(activatingSelection: false)
            }
        }
    }

    private func promptForAccessibilityIfNeeded() {
        guard !promptedForAccessibility, !AccessibilityPermissions.isGranted() else { return }
        promptedForAccessibility = true
        AccessibilityPermissions.promptIfNeeded()
    }

    /// How many cells fit in one row on the active screen.
    private func optimalColumns(for count: Int) -> Int {
        guard count > 0 else { return 1 }
        let screen = NSScreen.main ?? NSScreen.screens.first
        let usable = (screen?.visibleFrame.width ?? 1440) * SwitcherMetrics.screenWidthBudget
        let cellTotal = SwitcherMetrics.cellWidth + SwitcherMetrics.cellSpacing
        let outerHorizontal = SwitcherMetrics.outerPadding * 2
        let maxCols = max(1, Int((usable - outerHorizontal + SwitcherMetrics.cellSpacing) / cellTotal))

        // Prefer a roughly balanced grid when there are many items, but
        // always stay within `maxCols` and within `maxRows`.
        let colsToFitInMaxRows = Int(ceil(Double(count) / Double(SwitcherMetrics.maxRows)))
        let cols = min(maxCols, max(colsToFitInMaxRows, min(count, maxCols)))
        return max(1, cols)
    }

    // MARK: - Keyboard handling

    private func installKeyMonitor() {
        // Always start fresh — earlier we used a `guard ... == nil`
        // shortcut which left stale handlers attached when a close
        // path skipped removal (e.g. drill-in folder commit).
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = Int(event.keyCode)
            let cmd = event.modifierFlags.contains(.command)
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let self, self.window?.isVisible == true else { return false }
                switch keyCode {
                // Cycle the active group without leaving the switcher.
                case kVK_ANSI_Grave:
                    let groups = self.groupsStore.groups
                    guard !groups.isEmpty else { return true }
                    let cur = groups.firstIndex(where: { $0.id == self.groupsStore.activeGroupID }) ?? -1
                    self.switchContent(to: groups[(cur + 1) % groups.count].id)
                    return true
                // Quick actions on the selected cell (require ⌘).
                case kVK_ANSI_W where cmd:
                    self.performAction(.close); return true
                case kVK_ANSI_H where cmd:
                    self.performAction(.hide); return true
                case kVK_ANSI_Q where cmd:
                    self.performAction(.quit); return true
                // Navigation.
                case kVK_Tab, kVK_RightArrow:
                    self.viewModel.selectNext(); return true
                case kVK_LeftArrow:
                    self.viewModel.selectPrevious(); return true
                case kVK_DownArrow:
                    self.viewModel.selectDown(); return true
                case kVK_UpArrow:
                    self.viewModel.selectUp(); return true
                case kVK_Return, kVK_ANSI_KeypadEnter:
                    self.close(activatingSelection: true); return true
                case kVK_Escape:
                    self.close(activatingSelection: false); return true
                default:
                    return false
                }
            }
            return handled ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    // MARK: - Modifier-release handling (Cmd+Tab metaphor)

    private func installFlagsMonitor() {
        removeFlagsMonitor()
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let optionStillHeld = event.modifierFlags.contains(.option)
            MainActor.assumeIsolated {
                guard let self, self.window?.isVisible == true else { return }
                if !optionStillHeld {
                    self.close(activatingSelection: true)
                }
            }
            return event
        }
    }

    private func removeFlagsMonitor() {
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
    }
}
