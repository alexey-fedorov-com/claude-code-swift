public struct TextView: View {
    public let content: String
    public let color: CellColor
    public let bold: Bool
    public let dim: Bool
    public let italic: Bool
    public let underline: Bool
    public let inverse: Bool

    public init(_ content: String, color: CellColor = .default,
                bold: Bool = false, dim: Bool = false, italic: Bool = false,
                underline: Bool = false, inverse: Bool = false) {
        self.content = content; self.color = color
        self.bold = bold; self.dim = dim; self.italic = italic
        self.underline = underline; self.inverse = inverse
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let yoga = YogaNode()
        yoga.text = content
        let lines = content.components(separatedBy: "\n")
        let maxW = lines.map { TextWrap.cellWidth($0) }.max() ?? 0
        yoga.width = .fixed(maxW)
        yoga.height = .fixed(lines.count)
        let style = CellStyle(fg: color, bold: bold, dim: dim, italic: italic,
                              underline: underline, inverse: inverse)
        let styleId = styles.id(for: style)
        let linesCopy = lines
        return LayoutNode(yoga: yoga) { screen, node in
            let x = node.yoga.layoutX
            let y = node.yoga.layoutY
            for (i, line) in linesCopy.enumerated() {
                screen.write(text: line, at: x, row: y + i, styleId: styleId)
            }
        }
    }
}

// MARK: - Legacy shim

@available(*, deprecated, renamed: "TextView")
public struct TextComponent {
    public let text: String
    public let attributes: TextAttributes
    public let padding: EdgeInsets

    public init(
        _ text: String,
        color: ANSIColor? = nil,
        background: ANSIColor? = nil,
        bold: Bool = false,
        italic: Bool = false,
        underline: Bool = false,
        dim: Bool = false,
        padding: EdgeInsets = .zero
    ) {
        self.text = text
        self.attributes = TextAttributes(
            color: color, background: background,
            bold: bold, italic: italic,
            underline: underline, dim: dim
        )
        self.padding = padding
    }

    public func buildNode() -> YogaNode {
        let node = YogaNode()
        node.text = text
        node.padding = padding
        node.width = .auto
        node.height = .auto
        return node
    }

    public func buildRenderNode(from yogaNode: YogaNode) -> RenderNode {
        return .text(
            x: yogaNode.layoutX, y: yogaNode.layoutY,
            width: yogaNode.layoutWidth, height: yogaNode.layoutHeight,
            content: text,
            attributes: attributes
        )
    }
}
