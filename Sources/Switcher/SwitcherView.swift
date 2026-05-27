import AppKit
import SwiftUI

// MARK: - Drop Target System

enum DropTargetKind: Equatable {
    case group(UUID)
    case app(String)
}

struct DropTarget: Equatable {
    let kind: DropTargetKind
    let frame: CGRect
}

struct DropTargetPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [DropTarget] = []
    static func reduce(value: inout [DropTarget], nextValue: () -> [DropTarget]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Switcher View

struct SwitcherView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject var groupsStore: GroupsStore
    let onCommit: () -> Void
    let onCancel: () -> Void
    let onAction: (Int, WindowAction) -> Void
    let onMouseTakeover: () -> Void
    let onSelectGroup: (AppGroup.ID) -> Void
    let onDropToGroup: (String, AppGroup.ID) -> Bool
    let onCreateGroup: (String, String) -> Void
    let onRemoveFromGroup: (String) -> Void
    @Namespace private var ns
    @State private var mouseTookOver = false

    @State private var dragBundleId: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragIcon: NSImage?
    @State private var dropTargets: [DropTarget] = []

    private var hoveredTarget: DropTarget? {
        guard dragBundleId != nil else { return nil }
        return dropTargets.first { $0.frame.contains(dragLocation) }
    }

    private var hoveredGroupID: UUID? {
        if case .group(let id) = hoveredTarget?.kind { return id }
        return nil
    }

    private var hoveredAppBundleId: String? {
        if case .app(let bid) = hoveredTarget?.kind, bid != dragBundleId { return bid }
        return nil
    }

    private var contentBlur: CGFloat {
        viewModel.contentPhase == .visible ? 0 : 16
    }

    private var contentScale: CGFloat {
        switch viewModel.contentPhase {
        case .visible: return 1
        case .zoomOut: return 0.92
        case .zoomIn: return 1.06
        }
    }

    private var contentOpacity: Double {
        viewModel.contentPhase == .visible ? 1 : 0
    }

    private var rows: [[(offset: Int, element: SwitcherCandidate)]] {
        let enumerated = Array(viewModel.candidates.enumerated())
        let cols = max(1, viewModel.columnsPerRow)
        return stride(from: 0, to: enumerated.count, by: cols).map {
            Array(enumerated[$0..<min($0 + cols, enumerated.count)])
        }
    }

    var body: some View {
        GlassEffectContainer(spacing: SwitcherMetrics.cellSpacing) {
            VStack(spacing: SwitcherMetrics.groupBarToGridSpacing) {
                GroupBarView(
                    groups: groupsStore.groups,
                    activeGroupID: groupsStore.activeGroupID,
                    namespace: ns,
                    onSelect: onSelectGroup,
                    dragTargetGroupID: hoveredGroupID
                )
                Group {
                    if viewModel.candidates.isEmpty {
                        EmptyGroupPlaceholder()
                    } else {
                        grid
                    }
                }
                .blur(radius: contentBlur)
                .scaleEffect(contentScale)
                .opacity(contentOpacity)
                .allowsHitTesting(viewModel.contentPhase == .visible)
            }
            .padding(SwitcherMetrics.outerPadding)
            .glassEffect(
                .clear,
                in: RoundedRectangle(cornerRadius: SwitcherMetrics.outerCornerRadius, style: .continuous)
            )
        }
        .coordinateSpace(name: "switcher")
        .overlay {
            if let icon = dragIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 48, height: 48)
                    .position(dragLocation)
                    .allowsHitTesting(false)
                    .opacity(0.85)
                    .shadow(radius: 8, y: 4)
            }
        }
        .onPreferenceChange(DropTargetPreferenceKey.self) { dropTargets = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.selectedIndex)
    }

    private var grid: some View {
        VStack(spacing: SwitcherMetrics.cellSpacing) {
            ForEach(0..<rows.count, id: \.self) { rowIdx in
                HStack(spacing: SwitcherMetrics.cellSpacing) {
                    ForEach(rows[rowIdx].indices, id: \.self) { i in
                        cell(for: rows[rowIdx][i])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for item: (offset: Int, element: SwitcherCandidate)) -> some View {
        let isSelected = item.offset == viewModel.selectedIndex
        switch item.element {
        case .folder(let group):
            FolderCell(
                group: group,
                isSelected: isSelected,
                namespace: ns,
                isDropTarget: hoveredGroupID == group.id
            )
            .onTapGesture {
                viewModel.selectedIndex = item.offset
                onCommit()
            }
            .onHover { hovering in if hovering { handleHover(at: item.offset) } }
        case .window(let entry):
            let isTarget = hoveredAppBundleId == entry.bundleId
            let activeGroup = groupsStore.activeGroup
            let isInGroup = !(activeGroup?.isAllGroup ?? true)
            WindowCell(
                entry: entry,
                isSelected: isSelected,
                namespace: ns,
                isDropTarget: isTarget,
                isDragSource: dragBundleId == entry.bundleId,
                onAction: { action in onAction(item.offset, action) },
                removeGroupName: isInGroup ? activeGroup?.name : nil,
                onRemove: isInGroup ? { onRemoveFromGroup(entry.bundleId) } : nil
            )
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("switcher"))
                    .onChanged { value in
                        let d = hypot(value.translation.width, value.translation.height)
                        if d > 5 {
                            if dragBundleId == nil {
                                dragBundleId = entry.bundleId
                                dragIcon = AppIconLoader.shared.icon(for: entry.bundleId)
                            }
                            dragLocation = value.location
                        }
                    }
                    .onEnded { value in
                        if let bid = dragBundleId {
                            commitDrop(bundleId: bid, at: value.location)
                            dragBundleId = nil
                            dragIcon = nil
                        } else {
                            viewModel.selectedIndex = item.offset
                            onCommit()
                        }
                    }
            )
            .onHover { hovering in if hovering { handleHover(at: item.offset) } }
        }
    }

    private func commitDrop(bundleId: String, at point: CGPoint) {
        guard let target = dropTargets.first(where: { $0.frame.contains(point) }) else { return }
        switch target.kind {
        case .group(let groupID):
            _ = onDropToGroup(bundleId, groupID)
        case .app(let targetBundleId):
            guard bundleId != targetBundleId else { return }
            onCreateGroup(bundleId, targetBundleId)
        }
    }

    private func handleHover(at index: Int) {
        viewModel.selectedIndex = index
        if !mouseTookOver {
            mouseTookOver = true
            onMouseTakeover()
        }
    }
}

// MARK: - Selection Highlight

private extension View {
    @ViewBuilder
    func selectionGlass(isSelected: Bool, namespace: Namespace.ID) -> some View {
        self.background {
            if isSelected {
                Color.clear
                    .glassEffect(
                        .clear.tint(.accentColor.opacity(0.5)).interactive(),
                        in: RoundedRectangle(cornerRadius: SwitcherMetrics.cellCornerRadius, style: .continuous)
                    )
                    .glassEffectID("selection", in: namespace)
            }
        }
    }
}

// MARK: - Window Cell

private struct WindowCell: View {
    let entry: WindowEntry
    let isSelected: Bool
    let namespace: Namespace.ID
    let isDropTarget: Bool
    let isDragSource: Bool
    let onAction: (WindowAction) -> Void
    var removeGroupName: String? = nil
    var onRemove: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 6) {
            appIcon
                .frame(width: SwitcherMetrics.iconSize, height: SwitcherMetrics.iconSize)
                .allowsHitTesting(false)
            Text(entry.appName)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .allowsHitTesting(false)
        }
        .padding(SwitcherMetrics.cellPadding)
        .frame(width: SwitcherMetrics.cellWidth)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DropTargetPreferenceKey.self,
                    value: [DropTarget(kind: .app(entry.bundleId), frame: geo.frame(in: .named("switcher")))]
                )
            }
        )
        .selectionGlass(isSelected: isSelected, namespace: namespace)
        .scaleEffect(isDropTarget ? 1.08 : 1.0)
        .opacity(isDragSource ? 0.4 : 1.0)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDropTarget)
        .animation(.easeOut(duration: 0.15), value: isDragSource)
        .contextMenu {
            if let onRemove, let name = removeGroupName {
                Button("Remove from \(name)") { onRemove() }
                Divider()
            }
            Button("Close Window") { onAction(.close) }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(entry.axElement == nil)
            Button("Hide App") { onAction(.hide) }
                .keyboardShortcut("h", modifiers: .command)
            Divider()
            Button("Quit App") { onAction(.quit) }
                .keyboardShortcut("q", modifiers: .command)
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = AppIconLoader.shared.icon(for: entry.bundleId) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.quaternary)
        }
    }
}

// MARK: - Folder Cell

private struct FolderCell: View {
    let group: AppGroup
    let isSelected: Bool
    let namespace: Namespace.ID
    let isDropTarget: Bool

    var body: some View {
        VStack(spacing: 6) {
            folderArt
                .frame(width: SwitcherMetrics.iconSize, height: SwitcherMetrics.iconSize)
                .allowsHitTesting(false)
            Text(group.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .allowsHitTesting(false)
        }
        .padding(SwitcherMetrics.cellPadding)
        .frame(width: SwitcherMetrics.cellWidth)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DropTargetPreferenceKey.self,
                    value: [DropTarget(kind: .group(group.id), frame: geo.frame(in: .named("switcher")))]
                )
            }
        )
        .selectionGlass(isSelected: isSelected, namespace: namespace)
        .scaleEffect(isDropTarget ? 1.04 : 1.0)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isDropTarget)
    }

    private var folderArt: some View {
        let entries = Array(group.entries.prefix(4))
        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.primary.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
                }
            miniIconsLayout(entries: entries)
                .padding(8)
        }
    }

    @ViewBuilder
    private func miniIconsLayout(entries: [AppEntry]) -> some View {
        if entries.isEmpty {
            EmptyView()
        } else if entries.count == 1 {
            miniIcon(for: entries[0].bundleIdentifier)
        } else if entries.count == 2 {
            HStack(spacing: 4) {
                miniIcon(for: entries[0].bundleIdentifier)
                miniIcon(for: entries[1].bundleIdentifier)
            }
        } else {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    miniIcon(for: entries[0].bundleIdentifier)
                    miniIcon(for: entries[1].bundleIdentifier)
                }
                HStack(spacing: 4) {
                    ForEach(2..<entries.count, id: \.self) { i in
                        miniIcon(for: entries[i].bundleIdentifier)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func miniIcon(for bundleId: String) -> some View {
        if let icon = AppIconLoader.shared.icon(for: bundleId) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 24, height: 24)
        } else {
            Color.clear.frame(width: 24, height: 24)
        }
    }
}

// MARK: - Empty Group Placeholder

private struct EmptyGroupPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No running apps")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(minWidth: 200)
    }
}
