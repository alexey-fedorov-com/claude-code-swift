public struct SpacerView: View {
    public init() {}

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let yoga = YogaNode()
        yoga.flexGrow = 1
        return LayoutNode(yoga: yoga) { _, _ in }
    }
}
