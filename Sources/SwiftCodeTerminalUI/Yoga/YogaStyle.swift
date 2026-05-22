/// Style enums for the minimal Yoga-like layout engine.
public enum FlexDirection: Sendable {
    case row
    case column
}

public enum JustifyContent: Sendable {
    case start
    case center
    case end
    case spaceBetween
    case spaceAround
}

public enum AlignItems: Sendable {
    case start
    case center
    case end
    case stretch
}

public enum Dimension: Sendable {
    case fixed(Int)
    case auto
    case percent(Double) // fraction of parent, 0.0–1.0
}

public struct EdgeInsets: Sendable {
    public var top: Int
    public var right: Int
    public var bottom: Int
    public var left: Int

    public static let zero = EdgeInsets(top: 0, right: 0, bottom: 0, left: 0)

    public init(top: Int = 0, right: Int = 0, bottom: Int = 0, left: Int = 0) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    public init(all value: Int) {
        self.init(top: value, right: value, bottom: value, left: value)
    }

    public init(horizontal: Int = 0, vertical: Int = 0) {
        self.init(top: vertical, right: horizontal, bottom: vertical, left: horizontal)
    }

    public var horizontal: Int { left + right }
    public var vertical: Int { top + bottom }
}

public enum BorderStyle: Sendable {
    case none
    case single
    case double
    case rounded
}
