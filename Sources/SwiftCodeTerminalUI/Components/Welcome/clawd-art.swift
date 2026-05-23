/// Hardcoded art rows ported verbatim from .reference/src/components/LogoV2/WelcomeV2.tsx
/// dark theme branch (the fallthrough block starting at line 107 — after Apple_Terminal
/// and light theme early-returns). Width matches reference WELCOME_V2_WIDTH = 58.
public enum ClawdArt {
    public struct Span: Sendable {
        public let text: String
        public let color: CellColor
        public let dim: Bool
        public let bold: Bool

        public init(_ text: String, color: CellColor = .default,
                    dim: Bool = false, bold: Bool = false) {
            self.text = text
            self.color = color
            self.dim = dim
            self.bold = bold
        }
    }

    public static let width = 58

    /// Header row: "Welcome to Swift Code v{version}"
    /// (Product renamed from "Claude Code" per the Swift port plan.)
    public static func headerSpans(version: String, theme: Theme) -> [Span] {
        [
            Span("Welcome to Swift Code ", color: theme.claude),
            Span("v\(version) ", dim: true),
        ]
    }

    /// Default dark theme rows ported verbatim from t1–t16 of WelcomeV2.tsx.
    /// Each row's spans are rendered left-to-right; text is unchanged from reference.
    ///
    /// Row mapping (TSX variable → index in returned array):
    ///   t1  → row 0   (58 × '…')
    ///   t2  → row 1   (58 spaces)
    ///   t3  → row 2   (*…█████▓▓░ pattern)
    ///   t4  → row 3
    ///   t5  → row 4
    ///   t6  → row 5
    ///   t7  → row 6   (mixed: plain / bold-* / plain)
    ///   t8  → row 7
    ///   t9  → row 8   (dim)
    ///   t10 → row 9   (dim)
    ///   t11 → row 10  (dim)
    ///   t13 → row 11  (clawd_body art + dim-* suffix)
    ///   t14 → row 12  (clawd_body art + bold-*)
    ///   t15 → row 13  (clawd_body art)
    ///   t16 → row 14  (closing ellipsis with clawd_body █ █   █ █)
    public static func darkRows(theme: Theme) -> [[Span]] {
        let body = theme.clawdBody

        return [
            // Row 0 — t1: 58 horizontal ellipsis chars
            [Span("…………………………………………………………………………………………………………………………………………………………")],

            // Row 1 — t2: 58 spaces (blank separator)
            [Span("                                                          ")],

            // Row 2 — t3
            [Span("     *                                       █████▓▓░     ")],

            // Row 3 — t4
            [Span("                                 *         ███▓░     ░░   ")],

            // Row 4 — t5
            [Span("            ░░░░░░                        ███▓░           ")],

            // Row 5 — t6
            [Span("    ░░░   ░░░░░░░░░░                      ███▓░           ")],

            // Row 6 — t7 (three spans: plain, bold *, plain)
            [
                Span("   ░░░░░░░░░░░░░░░░░░░    "),
                Span("*", bold: true),
                Span("                ██▓░░      ▓   "),
            ],

            // Row 7 — t8
            [Span("                                             ░▓▓███▓▓░    ")],

            // Row 8 — t9 (dim)
            [Span(" *                                 ░░░░                   ", dim: true)],

            // Row 9 — t10 (dim)
            [Span("                                 ░░░░░░░░                 ", dim: true)],

            // Row 10 — t11 (dim)
            [Span("                               ░░░░░░░░░░░░░░░░           ", dim: true)],

            // Row 11 — t13: "      " + clawd_body( █████████ ) + suffix + dim("*") + " "
            [
                Span("      "),
                Span(" █████████ ", color: body),
                Span("                                       "),
                Span("*", dim: true),
                Span(" "),
            ],

            // Row 12 — t14: "      " + clawd_body(██▄█████▄██) + mid + bold("*") + end
            [
                Span("      "),
                Span("██▄█████▄██", color: body),
                Span("                        "),
                Span("*", bold: true),
                Span("                "),
            ],

            // Row 13 — t15: "      " + clawd_body( █████████ ) + suffix
            [
                Span("      "),
                Span(" █████████ ", color: body),
                Span("     *                                   "),
            ],

            // Row 14 — t16: 7 ellipses + clawd_body(█ █   █ █) + 42 ellipses
            [
                Span("…………………"),
                Span("█ █   █ █", color: body),
                Span("…………………………………………………………………………………………………………"),
            ],
        ]
    }
}
