import Foundation

/// Modal-style screen rendered when `ChatScreenState.loginFlow` is non-nil.
///
/// Replaces the chat area while active. Lays out a centered rounded card
/// whose body varies by `LoginFlowState`.
public struct LoginScreen: View {
    public let flow: LoginFlowState
    public let spinnerFrame: Int
    public let width: Int

    public init(flow: LoginFlowState, spinnerFrame: Int = 0, width: Int = 80) {
        self.flow = flow
        self.spinnerFrame = spinnerFrame
        self.width = width
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let cardWidth = max(min(width - 4, 72), 40)

        let borderStyleId = styles.id(for: CellStyle(fg: theme.claude))
        let titleStyleId = styles.id(for: CellStyle(fg: theme.claude, bold: true))
        let textStyleId = styles.id(for: CellStyle())
        let dimStyleId = styles.id(for: CellStyle(dim: true))
        let successStyleId = styles.id(for: CellStyle(fg: theme.success, bold: true))
        let errorStyleId = styles.id(for: CellStyle(fg: theme.error, bold: true))
        let promptStyleId = styles.id(for: CellStyle(fg: theme.claude))

        let body = renderBody(spinnerFrame: spinnerFrame)
        let cardHeight = 2 + body.lines.count + 2  // border + pad + content + pad + border (we inline pad in body)

        let yoga = YogaNode()
        yoga.width = .fixed(cardWidth)
        yoga.height = .fixed(cardHeight)

        let title = body.title
        let lines = body.lines

        return LayoutNode(yoga: yoga) { screen, node in
            let x = node.yoga.layoutX
            let y = node.yoga.layoutY
            let w = node.yoga.layoutWidth
            let h = node.yoga.layoutHeight
            guard w >= 6 && h >= 4 else { return }

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

            // Title overlay on top border
            let label = " \(title) "
            let labelWidth = TextWrap.cellWidth(label)
            if labelWidth + 4 < w {
                screen.write(text: label, at: x + 2, row: y, styleId: titleStyleId)
            }

            // Body lines, left-padded by 2.
            for (i, line) in lines.enumerated() {
                let row = y + 1 + i
                guard row < y + h - 1 else { break }
                let styleId: Int
                switch line.style {
                case .text: styleId = textStyleId
                case .dim: styleId = dimStyleId
                case .success: styleId = successStyleId
                case .error: styleId = errorStyleId
                case .prompt: styleId = promptStyleId
                }
                let maxBodyWidth = w - 4
                let text = LoginScreen.truncate(line.text, to: maxBodyWidth)
                screen.write(text: text, at: x + 2, row: row, styleId: styleId)
            }
        }
    }

    // MARK: - Body Builder

    enum LineStyle { case text, dim, success, error, prompt }
    struct Line { let text: String; let style: LineStyle }
    struct Body { let title: String; let lines: [Line] }

    func renderBody(spinnerFrame: Int) -> Body {
        switch flow {
        case .menu:
            return Body(title: "Sign in to Anthropic", lines: [
                Line(text: "", style: .text),
                Line(text: "Choose a sign-in method:", style: .text),
                Line(text: "", style: .text),
                Line(text: "  1  Paste an API key (sk-ant-…)", style: .text),
                Line(text: "  2  Sign in with Claude (browser OAuth)", style: .text),
                Line(text: "", style: .text),
                Line(text: "esc to cancel", style: .dim),
            ])

        case .apiKeyEntry(let buffer):
            let masked = String(repeating: "•", count: buffer.count)
            return Body(title: "Enter API Key", lines: [
                Line(text: "", style: .text),
                Line(text: "Paste your Anthropic API key (sk-ant-…):", style: .text),
                Line(text: "", style: .text),
                Line(text: "> \(masked)█", style: .prompt),
                Line(text: "", style: .text),
                Line(text: "We'll validate against api.anthropic.com and save", style: .dim),
                Line(text: "to the macOS Keychain.", style: .dim),
                Line(text: "", style: .text),
                Line(text: "enter to submit · esc to cancel", style: .dim),
            ])

        case .validatingApiKey:
            let frame = Spinner.dotsFrames[spinnerFrame % Spinner.dotsFrames.count]
            return Body(title: "Validating", lines: [
                Line(text: "", style: .text),
                Line(text: "\(frame) Checking API key with api.anthropic.com…", style: .text),
                Line(text: "", style: .text),
                Line(text: "ctrl+c to cancel", style: .dim),
            ])

        case .oauthWaiting(let url):
            return Body(title: "Sign in with Claude", lines: [
                Line(text: "", style: .text),
                Line(text: "Your browser should open automatically.", style: .text),
                Line(text: "If not, copy this URL:", style: .text),
                Line(text: "", style: .text),
                Line(text: url, style: .prompt),
                Line(text: "", style: .text),
                Line(text: "Waiting for callback (5 min timeout)…", style: .dim),
                Line(text: "", style: .text),
                Line(text: "esc to cancel", style: .dim),
            ])

        case .oauthExchanging:
            let frame = Spinner.dotsFrames[spinnerFrame % Spinner.dotsFrames.count]
            return Body(title: "Exchanging Code", lines: [
                Line(text: "", style: .text),
                Line(text: "\(frame) Exchanging authorization code for tokens…", style: .text),
                Line(text: "", style: .text),
            ])

        case .success(let message):
            return Body(title: "Signed In", lines: [
                Line(text: "", style: .text),
                Line(text: "✓ \(message)", style: .success),
                Line(text: "", style: .text),
                Line(text: "press any key to continue", style: .dim),
            ])

        case .error(let message):
            return Body(title: "Sign-In Failed", lines: [
                Line(text: "", style: .text),
                Line(text: "✗ \(message)", style: .error),
                Line(text: "", style: .text),
                Line(text: "press any key to dismiss", style: .dim),
            ])
        }
    }

    static func truncate(_ s: String, to maxCells: Int) -> String {
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
