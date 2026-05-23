public struct NewlineView: View {
    public init() {}

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let yoga = YogaNode()
        yoga.width = .fixed(0); yoga.height = .fixed(1)
        return LayoutNode(yoga: yoga) { _, _ in }
    }
}
