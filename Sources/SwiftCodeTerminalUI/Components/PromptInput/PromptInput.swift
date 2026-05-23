public struct PromptInput: View {
    public let cursor: TextCursor
    public let placeholder: String
    public let width: Int

    public init(cursor: TextCursor, placeholder: String = "", width: Int) {
        self.cursor = cursor
        self.placeholder = placeholder
        self.width = width
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let isEmpty = cursor.text.isEmpty
        let displayText = isEmpty ? placeholder : cursor.text
        let row = BoxView(width: .auto, height: .fixed(1), flexDirection: .row, children: [
            TextView("> ", color: theme.text),
            TextView(displayText, dim: isEmpty),
        ])
        return BoxView(
            width: .fixed(width),
            padding: EdgeInsets(horizontal: 1),
            border: .rounded,
            borderColor: .ansi256(240),
            flexDirection: .column,
            children: [row]
        ).buildLayoutNode(theme: theme, styles: styles)
    }
}
