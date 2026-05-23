public enum ScreenDiff {
    public static func compute(prev: Screen, next: Screen, styles: CellStyleTable) -> String {
        guard prev.width == next.width, prev.height == next.height else {
            return computeInitial(next: next, styles: styles)
        }
        var out = ""
        var currentStyle: CellStyleTable.StyleID = 0
        for row in 0..<next.height {
            var col = 0
            while col < next.width {
                if prev.cell(at: col, row: row) == next.cell(at: col, row: row) {
                    col += 1
                    continue
                }
                out += ANSIEscapes.cursorTo(row: row + 1, col: col + 1)
                while col < next.width && prev.cell(at: col, row: row) != next.cell(at: col, row: row) {
                    let cell = next.cell(at: col, row: row)
                    if cell.styleId != currentStyle {
                        out += ANSIEscapes.sgrReset
                        out += styles.style(for: cell.styleId).sgrOpen()
                        currentStyle = cell.styleId
                    }
                    out += String(cell.character)
                    col += 1
                }
            }
        }
        if !out.isEmpty {
            out += ANSIEscapes.sgrReset
        }
        return out
    }

    public static func computeInitial(next: Screen, styles: CellStyleTable) -> String {
        var out = ANSIEscapes.clearScreen + ANSIEscapes.cursorTo(row: 1, col: 1)
        var currentStyle: CellStyleTable.StyleID = 0
        for row in 0..<next.height {
            out += ANSIEscapes.cursorTo(row: row + 1, col: 1)
            for col in 0..<next.width {
                let cell = next.cell(at: col, row: row)
                if cell.styleId != currentStyle {
                    out += ANSIEscapes.sgrReset
                    out += styles.style(for: cell.styleId).sgrOpen()
                    currentStyle = cell.styleId
                }
                out += String(cell.character)
            }
        }
        out += ANSIEscapes.sgrReset
        return out
    }
}
