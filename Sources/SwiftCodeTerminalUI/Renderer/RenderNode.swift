/// The internal scene graph — produced from a YogaNode tree after layout.
/// Each RenderNode has computed bounds and rendering attributes.

public struct ANSIColor: Sendable {
    public let code: Int // ANSI color code (30-37 fg, 40-47 bg, 90-97 bright fg, 100-107 bright bg)

    public init(_ code: Int) { self.code = code }

    public static let black   = ANSIColor(30)
    public static let red     = ANSIColor(31)
    public static let green   = ANSIColor(32)
    public static let yellow  = ANSIColor(33)
    public static let blue    = ANSIColor(34)
    public static let magenta = ANSIColor(35)
    public static let cyan    = ANSIColor(36)
    public static let white   = ANSIColor(37)
    public static let brightBlack   = ANSIColor(90)
    public static let brightRed     = ANSIColor(91)
    public static let brightGreen   = ANSIColor(92)
    public static let brightYellow  = ANSIColor(93)
    public static let brightBlue    = ANSIColor(94)
    public static let brightMagenta = ANSIColor(95)
    public static let brightCyan    = ANSIColor(96)
    public static let brightWhite   = ANSIColor(97)
}

public struct TextAttributes: Sendable {
    public var color: ANSIColor? = nil
    public var background: ANSIColor? = nil
    public var bold: Bool = false
    public var italic: Bool = false
    public var underline: Bool = false
    public var dim: Bool = false

    public init(color: ANSIColor? = nil, background: ANSIColor? = nil,
                bold: Bool = false, italic: Bool = false,
                underline: Bool = false, dim: Bool = false) {
        self.color = color
        self.background = background
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.dim = dim
    }

    /// Produces the ANSI escape sequence prefix (empty if no attributes).
    public func ansiOpen() -> String {
        var codes: [Int] = []
        if bold      { codes.append(1) }
        if dim       { codes.append(2) }
        if italic    { codes.append(3) }
        if underline { codes.append(4) }
        if let fg = color      { codes.append(fg.code) }
        if let bg = background { codes.append(bg.code + 10) }
        guard !codes.isEmpty else { return "" }
        return "\u{1B}[\(codes.map(String.init).joined(separator: ";"))m"
    }

    /// Reset sequence (only when needed).
    public func ansiClose() -> String {
        let hasAttr = bold || dim || italic || underline || color != nil || background != nil
        return hasAttr ? "\u{1B}[0m" : ""
    }
}

// MARK: - RenderNode

public indirect enum RenderNode {
    case text(
        x: Int, y: Int, width: Int, height: Int,
        content: String,
        attributes: TextAttributes
    )
    case box(
        x: Int, y: Int, width: Int, height: Int,
        border: BorderStyle,
        children: [RenderNode]
    )
}

extension RenderNode {
    public var x: Int {
        switch self {
        case .text(let x, _, _, _, _, _): return x
        case .box(let x, _, _, _, _, _):  return x
        }
    }
    public var y: Int {
        switch self {
        case .text(_, let y, _, _, _, _): return y
        case .box(_, let y, _, _, _, _):  return y
        }
    }
    public var width: Int {
        switch self {
        case .text(_, _, let w, _, _, _): return w
        case .box(_, _, let w, _, _, _):  return w
        }
    }
    public var height: Int {
        switch self {
        case .text(_, _, _, let h, _, _): return h
        case .box(_, _, _, let h, _, _):  return h
        }
    }
}

// MARK: - Build RenderNode from YogaNode

public extension RenderNode {
    /// Converts a fully-laid-out YogaNode tree into a RenderNode tree.
    static func build(from yoga: YogaNode,
                      border: BorderStyle = .none,
                      attributes: TextAttributes = TextAttributes()) -> RenderNode {
        if yoga.children.isEmpty {
            return .text(
                x: yoga.layoutX, y: yoga.layoutY,
                width: yoga.layoutWidth, height: yoga.layoutHeight,
                content: yoga.text ?? "",
                attributes: attributes
            )
        } else {
            let childNodes = yoga.children.map { child in
                RenderNode.build(from: child, border: .none, attributes: TextAttributes())
            }
            return .box(
                x: yoga.layoutX, y: yoga.layoutY,
                width: yoga.layoutWidth, height: yoga.layoutHeight,
                border: border,
                children: childNodes
            )
        }
    }
}
