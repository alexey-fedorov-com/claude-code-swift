public struct ScreenCell: Equatable, Sendable {
    public var character: Character
    public var width: Int
    public var styleId: CellStyleTable.StyleID

    public static let blank = ScreenCell(character: " ", width: 1, styleId: 0)
}

public struct Screen: Sendable {
    public let width: Int
    public let height: Int
    public private(set) var cells: [ScreenCell]

    public init(width: Int, height: Int) {
        self.width = max(0, width)
        self.height = max(0, height)
        self.cells = Array(repeating: .blank, count: self.width * self.height)
    }

    public func cell(at col: Int, row: Int) -> ScreenCell {
        guard col >= 0 && col < width && row >= 0 && row < height else { return .blank }
        return cells[row * width + col]
    }

    public mutating func setCell(_ cell: ScreenCell, at col: Int, row: Int) {
        guard col >= 0 && col < width && row >= 0 && row < height else { return }
        cells[row * width + col] = cell
    }

    public mutating func write(text: String, at col: Int, row: Int, styleId: CellStyleTable.StyleID) {
        var c = col
        for ch in text {
            setCell(ScreenCell(character: ch, width: 1, styleId: styleId), at: c, row: row)
            c += 1
            if c >= width { return }
        }
    }
}
