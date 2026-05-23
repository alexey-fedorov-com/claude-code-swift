/// A node in the Yoga-like layout tree.
/// Each node either contains children (Box) or content (Text).
public class YogaNode {
    // Style
    public var flexDirection: FlexDirection = .column
    public var justifyContent: JustifyContent = .start
    public var alignItems: AlignItems = .start
    public var width: Dimension = .auto
    public var height: Dimension = .auto
    public var padding: EdgeInsets = .zero
    public var margin: EdgeInsets = .zero
    public var flexGrow: Double = 0.0
    public var flexShrink: Double = 1.0
    public var gap: Int = 0
    public var alignSelf: AlignSelf = .auto
    public var display: Display = .flex
    public var minWidth: Int? = nil
    public var maxWidth: Int? = nil

    // Content (for leaf text nodes)
    public var text: String? = nil

    // Children
    public var children: [YogaNode] = []

    // Computed layout (set by YogaCalculator)
    public internal(set) var layoutX: Int = 0
    public internal(set) var layoutY: Int = 0
    public internal(set) var layoutWidth: Int = 0
    public internal(set) var layoutHeight: Int = 0

    public init() {}

    /// Convenience: set fixed size.
    public func size(width: Int, height: Int) -> YogaNode {
        self.width = .fixed(width)
        self.height = .fixed(height)
        return self
    }

    public func addChild(_ child: YogaNode) {
        children.append(child)
    }
}
