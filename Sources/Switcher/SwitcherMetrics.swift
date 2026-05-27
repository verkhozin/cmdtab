import CoreGraphics

/// Single source of truth for switcher dimensions. Used by both the
/// SwiftUI view (rendering) and the coordinator (computing how many
/// columns fit on the active screen).
enum SwitcherMetrics {
    static let iconSize: CGFloat = 80
    static let cellWidth: CGFloat = 112
    static let cellPadding: CGFloat = 12
    static let cellSpacing: CGFloat = 10
    static let cellCornerRadius: CGFloat = 18
    static let outerPadding: CGFloat = 20
    static let outerCornerRadius: CGFloat = 28
    static let maxRows: Int = 4
    static let screenWidthBudget: CGFloat = 0.9

    // Group bar
    static let chipHorizontalPadding: CGFloat = 14
    static let chipVerticalPadding: CGFloat = 6
    static let chipSpacing: CGFloat = 4
    static let groupBarToGridSpacing: CGFloat = 16
}
