import SwiftUI

struct GroupBarView: View {
    let groups: [AppGroup]
    let activeGroupID: AppGroup.ID?
    let namespace: Namespace.ID
    let onSelect: (AppGroup.ID) -> Void
    let dragTargetGroupID: UUID?

    var body: some View {
        HStack(spacing: SwitcherMetrics.chipSpacing) {
            ForEach(groups) { group in
                GroupChip(
                    group: group,
                    isActive: group.id == activeGroupID,
                    namespace: namespace,
                    onSelect: { onSelect(group.id) },
                    isDropTarget: dragTargetGroupID == group.id
                )
            }
        }
    }
}

private struct GroupChip: View {
    let group: AppGroup
    let isActive: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void
    let isDropTarget: Bool

    @State private var isHovered = false

    var body: some View {
        Text(group.name)
            .font(.callout.weight(isActive ? .semibold : .medium))
            .foregroundStyle(isActive ? .primary : .secondary)
            .padding(.horizontal, SwitcherMetrics.chipHorizontalPadding)
            .padding(.vertical, SwitcherMetrics.chipVerticalPadding)
            .background {
                if isActive {
                    Color.clear
                        .glassEffect(
                            .clear.tint(.accentColor.opacity(0.45)).interactive(),
                            in: .capsule
                        )
                        .glassEffectID("activeGroup", in: namespace)
                } else {
                    Capsule()
                        .fill(.primary.opacity(isHovered || isDropTarget ? 0.1 : 0.04))
                        .overlay(Capsule().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
                }
            }
            .scaleEffect(isDropTarget ? 1.08 : 1.0)
            .contentShape(.capsule)
            .onTapGesture(perform: onSelect)
            .onHover { isHovered = $0 }
            .background {
                if !group.isAllGroup {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: DropTargetPreferenceKey.self,
                            value: [DropTarget(kind: .group(group.id), frame: geo.frame(in: .named("switcher")))]
                        )
                    }
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.78), value: isDropTarget)
            .help(group.isAllGroup ? "All running apps" : "Click to switch · drag apps to add")
    }
}
