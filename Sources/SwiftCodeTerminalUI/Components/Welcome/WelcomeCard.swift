/// Compact welcome card shown on REPL startup.
///
/// Mirrors the reference `LogoV2` compact layout: a rounded border with
/// " Swift Code v{version} " inlaid on the top edge, a small 3-row Clawd
/// piggy face centered inside, a "Welcome back!" greeting, and optional
/// model / cwd lines below.
///
/// The giant ASCII banner from `WelcomeBanner` is reserved for onboarding /
/// theme selection (a future task); the normal startup uses this card.
public struct WelcomeCard: View {
    public let version: String
    public let username: String?
    public let model: String?
    public let cwd: String?
    public let width: Int

    public init(version: String, username: String? = nil,
                model: String? = nil, cwd: String? = nil,
                width: Int = 80) {
        self.version = version
        self.username = username
        self.model = model
        self.cwd = cwd
        self.width = width
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let cardWidth = max(min(width - 2, 64), 32)

        let greeting = username.map { "Welcome back \($0)!" } ?? "Welcome back!"
        let title = " Swift Code v\(version) "

        // Style ids
        let borderStyleId = styles.id(for: CellStyle(fg: theme.dim))
        let titleStyleId = styles.id(for: CellStyle(fg: theme.claude, bold: true))
        let versionStyleId = styles.id(for: CellStyle(fg: theme.dim))
        let bodyStyleId = styles.id(for: CellStyle(fg: theme.clawdBody))
        let eyeStyleId = styles.id(for: CellStyle(fg: theme.clawdBody, bg: theme.clawdBackground))
        let textStyleId = styles.id(for: CellStyle())
        let dimStyleId = styles.id(for: CellStyle(dim: true))

        // Compute card height: top border + pad + 3 pig rows + blank +
        // greeting + (model?) + (cwd?) + pad + bottom border
        let pigRows = 3
        let infoRows = 1 + (model == nil ? 0 : 1) + (cwd == nil ? 0 : 1)
        let cardHeight = 1 + 1 + pigRows + 1 + infoRows + 1 + 1

        // Pre-render the colored title (claude-colored name + dim version)
        // so we can position it precisely on the top border.
        let productName = " Swift Code "
        let versionLabel = "v\(version) "
        let titleVisibleWidth = productName.count + versionLabel.count
        let _ = title  // kept for code-search; actual paint uses the two halves

        let yoga = YogaNode()
        yoga.width = .fixed(cardWidth)
        yoga.height = .fixed(cardHeight)

        let cwdValue = cwd
        let modelValue = model
        let greetingValue = greeting

        return LayoutNode(yoga: yoga) { screen, node in
            let x = node.yoga.layoutX
            let y = node.yoga.layoutY
            let w = node.yoga.layoutWidth
            let h = node.yoga.layoutHeight
            guard w >= 4 && h >= 4 else { return }

            // Rounded border
            screen.write(text: "╭", at: x, row: y, styleId: borderStyleId)
            screen.write(text: "╮", at: x + w - 1, row: y, styleId: borderStyleId)
            screen.write(text: "╰", at: x, row: y + h - 1, styleId: borderStyleId)
            screen.write(text: "╯", at: x + w - 1, row: y + h - 1, styleId: borderStyleId)
            screen.write(text: String(repeating: "─", count: w - 2),
                         at: x + 1, row: y, styleId: borderStyleId)
            screen.write(text: String(repeating: "─", count: w - 2),
                         at: x + 1, row: y + h - 1, styleId: borderStyleId)
            for r in (y + 1)..<(y + h - 1) {
                screen.write(text: "│", at: x, row: r, styleId: borderStyleId)
                screen.write(text: "│", at: x + w - 1, row: r, styleId: borderStyleId)
            }

            // Title overlay on top border: "╭─ Swift Code vX.Y.Z ─...─╮"
            let titleStart = x + 2
            if titleStart + titleVisibleWidth < x + w - 2 {
                screen.write(text: productName, at: titleStart, row: y, styleId: titleStyleId)
                screen.write(text: versionLabel,
                             at: titleStart + productName.count, row: y,
                             styleId: versionStyleId)
            }

            // Small Clawd piggy — centered. The pig is 9 cols wide.
            // Row 1: " ▐" body + "▛███▜" eyes(bg) + "▌" body  (cols 0..7)
            // Row 2: "▝▜" body + "█████" eyes(bg) + "▛▘" body (cols 0..8)
            // Row 3: "  ▘▘ ▝▝  " feet                          (cols 0..8)
            let pigWidth = 9
            let pigLeft = x + (w - pigWidth) / 2
            let pigTop = y + 2

            screen.write(text: " ▐", at: pigLeft, row: pigTop, styleId: bodyStyleId)
            screen.write(text: "▛███▜", at: pigLeft + 2, row: pigTop, styleId: eyeStyleId)
            screen.write(text: "▌", at: pigLeft + 7, row: pigTop, styleId: bodyStyleId)

            screen.write(text: "▝▜", at: pigLeft, row: pigTop + 1, styleId: bodyStyleId)
            screen.write(text: "█████", at: pigLeft + 2, row: pigTop + 1, styleId: eyeStyleId)
            screen.write(text: "▛▘", at: pigLeft + 7, row: pigTop + 1, styleId: bodyStyleId)

            screen.write(text: "  ▘▘ ▝▝  ",
                         at: pigLeft, row: pigTop + 2, styleId: bodyStyleId)

            // Centered text rows below the pig (separated by one blank row)
            var row = pigTop + pigRows + 1
            let center: (String) -> Int = { s in
                x + (w - TextWrap.cellWidth(s)) / 2
            }

            screen.write(text: greetingValue,
                         at: center(greetingValue), row: row, styleId: textStyleId)
            row += 1
            if let m = modelValue {
                let shown = WelcomeCard.truncateToWidth(m, maxCells: w - 4)
                screen.write(text: shown, at: center(shown), row: row, styleId: dimStyleId)
                row += 1
            }
            if let c = cwdValue {
                let shown = WelcomeCard.truncateToWidth(c, maxCells: w - 4)
                screen.write(text: shown, at: center(shown), row: row, styleId: dimStyleId)
                row += 1
            }
        }
    }

    /// Truncate `s` to at most `maxCells` visible columns, appending `…`.
    static func truncateToWidth(_ s: String, maxCells: Int) -> String {
        guard maxCells > 0 else { return "" }
        if TextWrap.cellWidth(s) <= maxCells { return s }
        var out = ""
        var used = 0
        for ch in s {
            let cw = TextWrap.cellWidth(String(ch))
            if used + cw + 1 > maxCells { break }
            out.append(ch)
            used += cw
        }
        return out + "…"
    }
}
