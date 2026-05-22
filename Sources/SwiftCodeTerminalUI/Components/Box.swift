/// Box component — a flex container that can hold children and optionally draw a border.
public struct BoxComponent {
    public let children: [BoxChild]
    public let width: Dimension
    public let height: Dimension
    public let padding: EdgeInsets
    public let margin: EdgeInsets
    public let border: BorderStyle
    public let flexDirection: FlexDirection
    public let justifyContent: JustifyContent
    public let alignItems: AlignItems

    public init(
        children: [BoxChild] = [],
        width: Dimension = .auto,
        height: Dimension = .auto,
        padding: EdgeInsets = .zero,
        margin: EdgeInsets = .zero,
        border: BorderStyle = .none,
        flexDirection: FlexDirection = .column,
        justifyContent: JustifyContent = .start,
        alignItems: AlignItems = .start
    ) {
        self.children = children
        self.width = width
        self.height = height
        self.padding = padding
        self.margin = margin
        self.border = border
        self.flexDirection = flexDirection
        self.justifyContent = justifyContent
        self.alignItems = alignItems
    }

    /// Convenience: box with a single-line border adds 1 cell of effective padding on all sides.
    public var effectivePadding: EdgeInsets {
        if border != .none {
            return EdgeInsets(
                top: padding.top + 1,
                right: padding.right + 1,
                bottom: padding.bottom + 1,
                left: padding.left + 1
            )
        }
        return padding
    }

    /// Build the yoga node tree for this box and its children.
    public func buildNode() -> YogaNode {
        let node = YogaNode()
        node.width = width
        node.height = height
        // When a border is drawn, we need extra space for it
        node.padding = effectivePadding
        node.margin = margin
        node.flexDirection = flexDirection
        node.justifyContent = justifyContent
        node.alignItems = alignItems
        for child in children {
            node.addChild(child.buildNode())
        }
        return node
    }

    /// Build a RenderNode from a fully laid-out yoga node.
    /// `yogaNode` must have been processed by YogaCalculator first.
    public func buildRenderNode(from yogaNode: YogaNode) -> RenderNode {
        let childRenderNodes = zip(children, yogaNode.children).map { child, childYoga in
            child.buildRenderNode(from: childYoga)
        }
        return .box(
            x: yogaNode.layoutX, y: yogaNode.layoutY,
            width: yogaNode.layoutWidth, height: yogaNode.layoutHeight,
            border: border,
            children: childRenderNodes
        )
    }
}

// MARK: - BoxChild

/// Either a Text or Box child inside a Box.
public enum BoxChild {
    case text(TextComponent)
    case box(BoxComponent)

    func buildNode() -> YogaNode {
        switch self {
        case .text(let t): return t.buildNode()
        case .box(let b): return b.buildNode()
        }
    }

    func buildRenderNode(from yogaNode: YogaNode) -> RenderNode {
        switch self {
        case .text(let t): return t.buildRenderNode(from: yogaNode)
        case .box(let b): return b.buildRenderNode(from: yogaNode)
        }
    }
}
