public struct BoxView: View {
    public let border: BorderStyle
    public let borderColor: CellColor
    public let width: Dimension
    public let height: Dimension
    public let padding: EdgeInsets
    public let margin: EdgeInsets
    public let flexDirection: FlexDirection
    public let justifyContent: JustifyContent
    public let alignItems: AlignItems
    public let gap: Int
    public let flexGrow: Double
    public let children: [any View]

    public init(width: Dimension = .auto, height: Dimension = .auto,
                padding: EdgeInsets = .zero, margin: EdgeInsets = .zero,
                border: BorderStyle = .none, borderColor: CellColor = .default,
                flexDirection: FlexDirection = .column,
                justifyContent: JustifyContent = .start,
                alignItems: AlignItems = .start,
                gap: Int = 0, flexGrow: Double = 0,
                children: [any View] = []) {
        self.width = width; self.height = height
        self.padding = padding; self.margin = margin
        self.border = border; self.borderColor = borderColor
        self.flexDirection = flexDirection; self.justifyContent = justifyContent
        self.alignItems = alignItems; self.gap = gap
        self.flexGrow = flexGrow; self.children = children
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let yoga = YogaNode()
        yoga.width = width; yoga.height = height
        yoga.margin = margin
        let borderInset = border == .none ? 0 : 1
        yoga.padding = EdgeInsets(
            top: padding.top + borderInset,
            right: padding.right + borderInset,
            bottom: padding.bottom + borderInset,
            left: padding.left + borderInset
        )
        yoga.flexDirection = flexDirection
        yoga.justifyContent = justifyContent
        yoga.alignItems = alignItems
        yoga.gap = gap
        yoga.flexGrow = flexGrow
        let bs = border
        let styleId = styles.id(for: CellStyle(fg: borderColor))
        let node = LayoutNode(yoga: yoga) { screen, node in
            guard bs != .none else { return }
            paintBorder(into: &screen, node: node, style: bs, styleId: styleId)
        }
        for child in children {
            node.addChild(child.buildLayoutNode(theme: theme, styles: styles))
        }
        return node
    }
}

private func paintBorder(into screen: inout Screen, node: LayoutNode,
                         style: BorderStyle, styleId: CellStyleTable.StyleID) {
    let x = node.yoga.layoutX
    let y = node.yoga.layoutY
    let w = node.yoga.layoutWidth
    let h = node.yoga.layoutHeight
    guard w >= 2 && h >= 2 else { return }
    let chars = borderChars(for: style)
    screen.write(text: String(chars.topLeft), at: x, row: y, styleId: styleId)
    screen.write(text: String(repeating: String(chars.horizontal), count: w - 2),
                 at: x + 1, row: y, styleId: styleId)
    screen.write(text: String(chars.topRight), at: x + w - 1, row: y, styleId: styleId)
    screen.write(text: String(chars.bottomLeft), at: x, row: y + h - 1, styleId: styleId)
    screen.write(text: String(repeating: String(chars.horizontal), count: w - 2),
                 at: x + 1, row: y + h - 1, styleId: styleId)
    screen.write(text: String(chars.bottomRight), at: x + w - 1, row: y + h - 1, styleId: styleId)
    for r in (y + 1)..<(y + h - 1) {
        screen.write(text: String(chars.vertical), at: x, row: r, styleId: styleId)
        screen.write(text: String(chars.vertical), at: x + w - 1, row: r, styleId: styleId)
    }
}

private struct BorderChars {
    let topLeft: Character; let topRight: Character
    let bottomLeft: Character; let bottomRight: Character
    let horizontal: Character; let vertical: Character
}

private func borderChars(for style: BorderStyle) -> BorderChars {
    switch style {
    case .none:
        return BorderChars(topLeft: " ", topRight: " ", bottomLeft: " ", bottomRight: " ", horizontal: " ", vertical: " ")
    case .single:
        return BorderChars(topLeft: "┌", topRight: "┐", bottomLeft: "└", bottomRight: "┘", horizontal: "─", vertical: "│")
    case .double:
        return BorderChars(topLeft: "╔", topRight: "╗", bottomLeft: "╚", bottomRight: "╝", horizontal: "═", vertical: "║")
    case .rounded:
        return BorderChars(topLeft: "╭", topRight: "╮", bottomLeft: "╰", bottomRight: "╯", horizontal: "─", vertical: "│")
    }
}

// MARK: - Legacy shims

@available(*, deprecated, renamed: "BoxView")
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

    public func buildNode() -> YogaNode {
        let node = YogaNode()
        node.width = width
        node.height = height
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

@available(*, deprecated, message: "Use [any View] children on BoxView instead")
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
