public struct MessageList: View {
    public let messages: [any View]
    public init(messages: [any View]) { self.messages = messages }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        var children: [any View] = []
        for (i, m) in messages.enumerated() {
            if i > 0 { children.append(NewlineView()) }
            children.append(m)
        }
        return BoxView(width: .auto, flexDirection: .column, children: children)
            .buildLayoutNode(theme: theme, styles: styles)
    }
}
