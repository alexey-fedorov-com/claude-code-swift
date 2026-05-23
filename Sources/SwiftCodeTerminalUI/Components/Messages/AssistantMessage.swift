public struct AssistantMessageView: View {
    public let text: String
    public init(text: String) { self.text = text }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        BoxView(width: .auto, flexDirection: .row, children: [
            TextView("● ", color: theme.claude),
            WrappedTextView(text: text, indent: 2),
        ]).buildLayoutNode(theme: theme, styles: styles)
    }
}

/// Wraps long text to parent's available width with a hanging indent on continuation lines.
public struct WrappedTextView: View {
    public let text: String
    public let indent: Int

    public init(text: String, indent: Int = 0) {
        self.text = text
        self.indent = indent
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let yoga = YogaNode()
        yoga.width = .auto
        yoga.flexGrow = 1
        let textCopy = text
        let indentCopy = indent
        let styleId = styles.id(for: CellStyle())
        return LayoutNode(yoga: yoga) { screen, node in
            let availW = max(1, node.yoga.layoutWidth)
            let lines = TextWrap.wrap(textCopy, width: availW)
            for (i, line) in lines.enumerated() {
                let prefix = i == 0 ? "" : String(repeating: " ", count: indentCopy)
                screen.write(text: prefix + line,
                             at: node.yoga.layoutX,
                             row: node.yoga.layoutY + i,
                             styleId: styleId)
            }
            // Force layoutHeight to actual rendered line count so the row above us
            // doesn't visually overlap. This is a v1 trade-off — proper measure phase deferred.
            node.yoga.layoutHeight = lines.count
        }
    }
}
