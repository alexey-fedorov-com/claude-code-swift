public struct SystemMessageView: View {
    public let text: String
    public init(text: String) { self.text = text }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        TextView("  \(text)", dim: true, italic: true)
            .buildLayoutNode(theme: theme, styles: styles)
    }
}
