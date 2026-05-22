/// Text component — renders a string with optional styling.
/// Produces a leaf YogaNode with associated TextAttributes.
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

    /// Build the yoga node for this text component.
    public func buildNode() -> YogaNode {
        let node = YogaNode()
        node.text = text
        node.padding = padding
        node.width = .auto
        node.height = .auto
        return node
    }

    /// Build a fully rendered RenderNode after layout has been computed.
    public func buildRenderNode(from yogaNode: YogaNode) -> RenderNode {
        return .text(
            x: yogaNode.layoutX, y: yogaNode.layoutY,
            width: yogaNode.layoutWidth, height: yogaNode.layoutHeight,
            content: text,
            attributes: attributes
        )
    }
}
