public struct PermissionRequestDialog: View {
    public enum Option: String, Sendable, CaseIterable {
        case allow = "Allow"
        case allowAlways = "Allow always"
        case deny = "Deny"
    }

    public let toolName: String
    public let description: String
    public let options: [Option]
    public let selectedIndex: Int

    public init(toolName: String, description: String,
                options: [Option] = [.allow, .allowAlways, .deny],
                selectedIndex: Int = 0) {
        self.toolName = toolName
        self.description = description
        self.options = options
        self.selectedIndex = selectedIndex
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        var rows: [any View] = [
            BoxView(width: .auto, flexDirection: .row, children: [
                TextView("● ", color: theme.permission),
                TextView("Tool permission requested", bold: true),
            ]),
            TextView("  \(toolName)", color: theme.claude),
            TextView("  \(description)", dim: true),
            NewlineView(),
        ]
        for (i, opt) in options.enumerated() {
            rows.append(BoxView(width: .auto, flexDirection: .row, children: [
                TextView(i == selectedIndex ? "> " : "  "),
                TextView(opt.rawValue, color: i == selectedIndex ? theme.claude : .default),
            ]))
        }
        return BoxView(width: .auto, padding: EdgeInsets(all: 1),
                       border: .rounded, borderColor: theme.permission,
                       flexDirection: .column, children: rows)
            .buildLayoutNode(theme: theme, styles: styles)
    }
}
