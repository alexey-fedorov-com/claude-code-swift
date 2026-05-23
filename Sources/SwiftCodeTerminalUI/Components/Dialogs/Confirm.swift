public struct ConfirmDialog: View {
    public enum Selection: Sendable { case yes, no }

    public let title: String
    public let detail: String?
    public let yesLabel: String
    public let noLabel: String
    public let selected: Selection

    public init(title: String, detail: String? = nil,
                yesLabel: String = "Yes", noLabel: String = "No",
                selected: Selection = .no) {
        self.title = title
        self.detail = detail
        self.yesLabel = yesLabel
        self.noLabel = noLabel
        self.selected = selected
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        var rows: [any View] = [
            TextView(title, bold: true),
        ]
        if let d = detail { rows.append(TextView(d, dim: true)) }
        rows.append(NewlineView())
        rows.append(BoxView(width: .auto, flexDirection: .row, children: [
            TextView(selected == .yes ? "> " : "  "),
            TextView(yesLabel, color: selected == .yes ? theme.claude : .default),
            TextView("   "),
            TextView(selected == .no ? "> " : "  "),
            TextView(noLabel, color: selected == .no ? theme.claude : .default),
        ]))
        return BoxView(width: .auto, padding: EdgeInsets(all: 1),
                       border: .rounded, borderColor: theme.warning,
                       flexDirection: .column, children: rows)
            .buildLayoutNode(theme: theme, styles: styles)
    }
}
