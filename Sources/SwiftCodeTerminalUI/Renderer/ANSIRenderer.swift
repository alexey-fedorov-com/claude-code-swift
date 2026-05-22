/// Renders a RenderNode tree to an ANSI string using a 2D character buffer.
public struct ANSIRenderer {

    public init() {}

    /// Renders the given node tree into an ANSI string.
    /// - Parameters:
    ///   - root: The root render node.
    ///   - width: Canvas width in columns.
    ///   - height: Canvas height in rows.
    public func render(root: RenderNode, width: Int, height: Int) -> String {
        var canvas = Canvas(width: width, height: height)
        draw(node: root, into: &canvas)
        return canvas.toString()
    }

    // MARK: - Drawing

    private func draw(node: RenderNode, into canvas: inout Canvas) {
        switch node {
        case .text(let x, let y, _, _, let content, let attrs):
            drawText(content: content, x: x, y: y, attributes: attrs, into: &canvas)

        case .box(let x, let y, let width, let height, let border, let children):
            if border != .none {
                drawBorder(x: x, y: y, width: width, height: height,
                           style: border, into: &canvas)
            }
            for child in children {
                draw(node: child, into: &canvas)
            }
        }
    }

    private func drawText(content: String, x: Int, y: Int,
                          attributes: TextAttributes, into canvas: inout Canvas) {
        let lines = content.components(separatedBy: "\n")
        let open = attributes.ansiOpen()
        let close = attributes.ansiClose()
        for (lineIdx, line) in lines.enumerated() {
            let row = y + lineIdx
            let formattedLine = open + line + close
            canvas.write(formattedLine, rawLength: line.count, at: x, row: row)
        }
    }

    private func drawBorder(x: Int, y: Int, width: Int, height: Int,
                             style: BorderStyle, into canvas: inout Canvas) {
        let chars = borderChars(for: style)
        guard width >= 2 && height >= 2 else { return }

        // Top row
        let topRow = chars.topLeft
            + String(repeating: chars.horizontal, count: max(0, width - 2))
            + chars.topRight
        canvas.write(topRow, rawLength: width, at: x, row: y)

        // Bottom row
        let bottomRow = chars.bottomLeft
            + String(repeating: chars.horizontal, count: max(0, width - 2))
            + chars.bottomRight
        canvas.write(bottomRow, rawLength: width, at: x, row: y + height - 1)

        // Side rows
        for row in (y + 1)..<(y + height - 1) {
            canvas.write(chars.vertical, rawLength: 1, at: x, row: row)
            canvas.write(chars.vertical, rawLength: 1, at: x + width - 1, row: row)
        }
    }

    // MARK: - Border character sets

    private struct BorderChars {
        let topLeft: String
        let topRight: String
        let bottomLeft: String
        let bottomRight: String
        let horizontal: String
        let vertical: String
    }

    private func borderChars(for style: BorderStyle) -> BorderChars {
        switch style {
        case .none:
            return BorderChars(topLeft: " ", topRight: " ", bottomLeft: " ",
                               bottomRight: " ", horizontal: " ", vertical: " ")
        case .single:
            return BorderChars(topLeft: "┌", topRight: "┐", bottomLeft: "└",
                               bottomRight: "┘", horizontal: "─", vertical: "│")
        case .double:
            return BorderChars(topLeft: "╔", topRight: "╗", bottomLeft: "╚",
                               bottomRight: "╝", horizontal: "═", vertical: "║")
        case .rounded:
            return BorderChars(topLeft: "╭", topRight: "╮", bottomLeft: "╰",
                               bottomRight: "╯", horizontal: "─", vertical: "│")
        }
    }
}

// MARK: - Canvas

/// A 2D grid of "cells". Each cell stores an attributed string chunk.
/// When multiple writes land on the same column, the last one wins.
struct Canvas {
    let width: Int
    let height: Int

    // rows[row][col] = (display text, raw char length it occupies)
    // We store full styled runs per cell write but track position by raw length.
    private var rows: [[(text: String, rawLen: Int)]]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        // Each row: empty
        rows = Array(repeating: [], count: max(1, height))
    }

    /// Writes a (possibly ANSI-escaped) string at (col, row).
    /// `rawLength` is the visible character count (for column tracking).
    mutating func write(_ text: String, rawLength: Int, at col: Int, row: Int) {
        guard row >= 0 && row < rows.count else { return }
        guard col >= 0 && col < width else { return }
        // Append a positioned write; we resolve during toString
        rows[row].append((text: "\u{FFFE}\(col):\(text)", rawLen: rawLength))
    }

    func toString() -> String {
        var output: [String] = []
        for row in rows {
            // Build a line: collect (col, text, rawLen) tuples
            var cells: [(col: Int, text: String, rawLen: Int)] = []
            for entry in row {
                let s = entry.text
                if s.hasPrefix("\u{FFFE}") {
                    let rest = String(s.dropFirst())
                    if let colonIdx = rest.firstIndex(of: ":") {
                        let colStr = String(rest[rest.startIndex..<colonIdx])
                        let text = String(rest[rest.index(after: colonIdx)...])
                        if let col = Int(colStr) {
                            cells.append((col: col, text: text, rawLen: entry.rawLen))
                        }
                    }
                }
            }
            // Sort by column
            cells.sort { $0.col < $1.col }
            // Render into a line buffer
            var line = ""
            var cursor = 0
            for cell in cells {
                if cell.col > cursor {
                    line += String(repeating: " ", count: cell.col - cursor)
                    cursor = cell.col
                }
                if cell.col == cursor {
                    line += cell.text
                    cursor += cell.rawLen
                }
            }
            output.append(line)
        }
        // Trim trailing empty lines
        while output.last?.isEmpty == true {
            output.removeLast()
        }
        return output.joined(separator: "\n")
    }
}
