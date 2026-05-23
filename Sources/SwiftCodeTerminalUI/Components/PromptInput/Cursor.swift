public struct TextCursor: Sendable, Equatable {
    public var text: String
    public var offset: Int

    public init(text: String = "", offset: Int = 0) {
        self.text = text
        self.offset = max(0, min(text.count, offset))
    }

    public mutating func insert(_ s: String) {
        let idx = text.index(text.startIndex, offsetBy: offset)
        text.insert(contentsOf: s, at: idx)
        offset += s.count
    }

    public mutating func backspace() {
        guard offset > 0 else { return }
        let prev = text.index(text.startIndex, offsetBy: offset - 1)
        text.remove(at: prev)
        offset -= 1
    }

    public mutating func delete() {
        guard offset < text.count else { return }
        let idx = text.index(text.startIndex, offsetBy: offset)
        text.remove(at: idx)
    }

    public mutating func moveLeft()  { offset = max(0, offset - 1) }
    public mutating func moveRight() { offset = min(text.count, offset + 1) }
    public mutating func moveHome()  { offset = 0 }
    public mutating func moveEnd()   { offset = text.count }
}
