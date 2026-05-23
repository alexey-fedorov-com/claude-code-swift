public enum TextWrap {
    /// Visible cell width of `text`, treating CJK / emoji as width 2.
    public static func cellWidth(_ text: String) -> Int {
        var total = 0
        for scalar in text.unicodeScalars {
            total += scalarWidth(scalar)
        }
        return total
    }

    /// Word-wrap `text` to lines of at most `width` cells. Honors existing newlines.
    public static func wrap(_ text: String, width: Int) -> [String] {
        guard width > 0 else { return [text] }
        if text.isEmpty { return [""] }
        var result: [String] = []
        for paragraph in text.components(separatedBy: "\n") {
            result.append(contentsOf: wrapParagraph(paragraph, width: width))
        }
        return result
    }

    private static func wrapParagraph(_ text: String, width: Int) -> [String] {
        if text.isEmpty { return [""] }
        var lines: [String] = []
        var current = ""
        var currentWidth = 0
        let words = splitWords(text)
        for word in words {
            let w = cellWidth(word)
            if word == " " {
                if currentWidth + 1 <= width {
                    current += " "
                    currentWidth += 1
                }
                continue
            }
            if currentWidth == 0 && w > width {
                // Word longer than line: hard-break
                var remaining = word
                while !remaining.isEmpty {
                    var take = ""
                    var takeWidth = 0
                    for ch in remaining {
                        let cw = cellWidth(String(ch))
                        if takeWidth + cw > width { break }
                        take.append(ch)
                        takeWidth += cw
                    }
                    if take.isEmpty {
                        take = String(remaining.first!)
                    }
                    lines.append(take)
                    remaining = String(remaining.dropFirst(take.count))
                }
                continue
            }
            if currentWidth + w > width {
                lines.append(current.trimmingTrailingSpace())
                current = ""
                currentWidth = 0
            }
            current += word
            currentWidth += w
        }
        if !current.isEmpty || lines.isEmpty {
            lines.append(current.trimmingTrailingSpace())
        }
        return lines
    }

    private static func splitWords(_ text: String) -> [String] {
        var words: [String] = []
        var current = ""
        for ch in text {
            if ch == " " {
                if !current.isEmpty { words.append(current); current = "" }
                words.append(" ")
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    private static func scalarWidth(_ scalar: Unicode.Scalar) -> Int {
        let v = scalar.value
        if v == 0 { return 0 }
        if v < 0x20 || (v >= 0x7F && v < 0xA0) { return 0 }
        if (v >= 0x1100 && v <= 0x115F) ||
           (v >= 0x2E80 && v <= 0x303E) ||
           (v >= 0x3041 && v <= 0x33FF) ||
           (v >= 0x3400 && v <= 0x4DBF) ||
           (v >= 0x4E00 && v <= 0x9FFF) ||
           (v >= 0xA000 && v <= 0xA4CF) ||
           (v >= 0xAC00 && v <= 0xD7A3) ||
           (v >= 0xF900 && v <= 0xFAFF) ||
           (v >= 0xFE30 && v <= 0xFE4F) ||
           (v >= 0xFF00 && v <= 0xFF60) ||
           (v >= 0xFFE0 && v <= 0xFFE6) ||
           (v >= 0x1F300 && v <= 0x1F64F) ||
           (v >= 0x1F900 && v <= 0x1F9FF) {
            return 2
        }
        return 1
    }
}

extension String {
    fileprivate func trimmingTrailingSpace() -> String {
        var s = self
        while s.hasSuffix(" ") { s.removeLast() }
        return s
    }
}
