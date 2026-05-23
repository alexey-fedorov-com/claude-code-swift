public enum CellColor: Hashable, Sendable {
    case `default`
    case ansi16(Int)
    case ansi256(Int)
    case rgb(UInt8, UInt8, UInt8)
}

public struct CellStyle: Hashable, Sendable {
    public var fg: CellColor
    public var bg: CellColor
    public var bold: Bool
    public var dim: Bool
    public var italic: Bool
    public var underline: Bool
    public var inverse: Bool
    public var strikethrough: Bool

    public init(fg: CellColor = .default, bg: CellColor = .default,
                bold: Bool = false, dim: Bool = false, italic: Bool = false,
                underline: Bool = false, inverse: Bool = false, strikethrough: Bool = false) {
        self.fg = fg; self.bg = bg; self.bold = bold; self.dim = dim
        self.italic = italic; self.underline = underline
        self.inverse = inverse; self.strikethrough = strikethrough
    }

    public static let `default` = CellStyle()

    public func sgrOpen() -> String {
        var codes: [String] = []
        if bold { codes.append("1") }
        if dim { codes.append("2") }
        if italic { codes.append("3") }
        if underline { codes.append("4") }
        if inverse { codes.append("7") }
        if strikethrough { codes.append("9") }
        switch fg {
        case .default: break
        case .ansi16(let n): codes.append("\(n)")
        case .ansi256(let n): codes.append("38;5;\(n)")
        case .rgb(let r, let g, let b): codes.append("38;2;\(r);\(g);\(b)")
        }
        switch bg {
        case .default: break
        case .ansi16(let n): codes.append("\(n + 10)")
        case .ansi256(let n): codes.append("48;5;\(n)")
        case .rgb(let r, let g, let b): codes.append("48;2;\(r);\(g);\(b)")
        }
        return codes.isEmpty ? "" : "\(ANSIEscapes.csi)\(codes.joined(separator: ";"))m"
    }
}

import Foundation

// Named CellStyleTable to avoid collision with the ApplicationServices C struct StyleTable.
public final class CellStyleTable: @unchecked Sendable {
    public typealias StyleID = Int
    private let lock = NSLock()
    private var styleToId: [CellStyle: StyleID] = [.default: 0]
    private var idToStyle: [CellStyle] = [.default]

    public init() {}

    public func id(for style: CellStyle) -> StyleID {
        lock.lock(); defer { lock.unlock() }
        if let id = styleToId[style] { return id }
        let id = idToStyle.count
        idToStyle.append(style)
        styleToId[style] = id
        return id
    }

    public func style(for id: StyleID) -> CellStyle {
        lock.lock(); defer { lock.unlock() }
        guard id >= 0 && id < idToStyle.count else { return .default }
        return idToStyle[id]
    }
}

