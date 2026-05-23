public struct Theme: Sendable {
    public let claude: CellColor
    public let clawdBody: CellColor
    public let clawdBackground: CellColor
    public let text: CellColor
    public let dim: CellColor
    public let permission: CellColor
    public let planMode: CellColor
    public let autoAccept: CellColor
    public let warning: CellColor
    public let error: CellColor
    public let success: CellColor

    public init(claude: CellColor, clawdBody: CellColor, clawdBackground: CellColor,
                text: CellColor, dim: CellColor, permission: CellColor,
                planMode: CellColor, autoAccept: CellColor,
                warning: CellColor, error: CellColor, success: CellColor) {
        self.claude = claude; self.clawdBody = clawdBody; self.clawdBackground = clawdBackground
        self.text = text; self.dim = dim; self.permission = permission
        self.planMode = planMode; self.autoAccept = autoAccept
        self.warning = warning; self.error = error; self.success = success
    }

    public static let `default` = Theme(
        claude: .rgb(215, 119, 87),
        clawdBody: .rgb(215, 119, 87),
        clawdBackground: .rgb(0, 0, 0),
        text: .default,
        dim: .ansi256(245),
        permission: .ansi256(33),
        planMode: .ansi256(99),
        autoAccept: .ansi256(40),
        warning: .ansi256(214),
        error: .ansi256(160),
        success: .ansi256(40)
    )
}
