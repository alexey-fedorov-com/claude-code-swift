public protocol View {
    func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode
}

public final class LayoutNode: @unchecked Sendable {
    public let yoga: YogaNode
    public let paint: (inout Screen, LayoutNode) -> Void
    public private(set) var children: [LayoutNode] = []

    public init(yoga: YogaNode, paint: @escaping (inout Screen, LayoutNode) -> Void) {
        self.yoga = yoga
        self.paint = paint
    }

    public func addChild(_ child: LayoutNode) {
        children.append(child)
        yoga.addChild(child.yoga)
    }
}

public func paint(node: LayoutNode, into screen: inout Screen) {
    node.paint(&screen, node)
    for child in node.children {
        paint(node: child, into: &screen)
    }
}

public func renderViewToScreen(_ view: any View, width: Int, height: Int,
                               theme: Theme = .default,
                               styles: CellStyleTable = CellStyleTable()) -> Screen {
    let root = view.buildLayoutNode(theme: theme, styles: styles)
    YogaCalculator().calculate(root: root.yoga, availableWidth: width, availableHeight: height)
    var screen = Screen(width: width, height: height)
    paint(node: root, into: &screen)
    return screen
}
