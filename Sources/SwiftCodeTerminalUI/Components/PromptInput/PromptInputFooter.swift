public struct PromptInputFooter: View {
    public let modeLabel: String?
    public let modeColor: CellColor
    public let shortcuts: [String]
    public let cwd: String?

    public init(modeLabel: String? = nil, modeColor: CellColor = .default,
                shortcuts: [String] = [], cwd: String? = nil) {
        self.modeLabel = modeLabel
        self.modeColor = modeColor
        self.shortcuts = shortcuts
        self.cwd = cwd
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        // Left group: mode label + cwd
        var leftChildren: [any View] = []
        if let label = modeLabel {
            leftChildren.append(TextView("⏵⏵ \(label) ", color: modeColor))
        }
        if let cwd = cwd {
            leftChildren.append(TextView(cwd, dim: true))
        }
        let leftGroup = BoxView(width: .auto, height: .fixed(1),
                                flexDirection: .row, children: leftChildren)

        // Right group: shortcuts
        var rightChildren: [any View] = []
        if !shortcuts.isEmpty {
            rightChildren.append(TextView(shortcuts.joined(separator: "  "), dim: true))
        }
        let rightGroup = BoxView(width: .auto, height: .fixed(1),
                                 flexDirection: .row, children: rightChildren)

        // Row with space-between pushes left and right groups apart
        return BoxView(width: .auto, height: .fixed(1),
                       flexDirection: .row,
                       justifyContent: .spaceBetween,
                       children: [leftGroup, rightGroup])
            .buildLayoutNode(theme: theme, styles: styles)
    }
}
