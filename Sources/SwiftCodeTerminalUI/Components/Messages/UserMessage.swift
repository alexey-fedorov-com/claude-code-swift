public struct UserMessageView: View {
    public let text: String
    public init(text: String) { self.text = text }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        BoxView(width: .auto, flexDirection: .row, children: [
            TextView("> ", dim: true),
            TextView(text),
        ]).buildLayoutNode(theme: theme, styles: styles)
    }
}
