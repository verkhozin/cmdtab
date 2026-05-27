import AppKit
import SwiftUI

final class SwitcherWindow: NSWindow {
    init<V: View>(rootView: V) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.hidesOnDeactivate = true

        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.registerForDraggedTypes([.string, .fileURL])
        self.contentView = hosting
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
