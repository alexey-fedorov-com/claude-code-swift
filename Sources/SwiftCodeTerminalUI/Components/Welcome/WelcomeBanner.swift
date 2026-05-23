/// WelcomeBanner renders the Clawd ASCII art welcome screen (dark theme variant).
/// Matches the reference .reference/src/components/LogoV2/WelcomeV2.tsx layout:
/// header row first, then 15 art rows at fixed width 58.
public struct WelcomeBanner: View {
    public let version: String

    public init(version: String) {
        self.version = version
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        var children: [any View] = []

        // Header: "Welcome to Swift Code v{version}"
        children.append(spansRow(ClawdArt.headerSpans(version: version, theme: theme)))

        // Art rows (dark theme)
        for row in ClawdArt.darkRows(theme: theme) {
            children.append(spansRow(row))
        }

        return BoxView(
            width: .fixed(ClawdArt.width),
            flexDirection: .column,
            children: children
        ).buildLayoutNode(theme: theme, styles: styles)
    }

    private func spansRow(_ spans: [ClawdArt.Span]) -> any View {
        let children: [any View] = spans.map { span in
            TextView(span.text, color: span.color, bold: span.bold, dim: span.dim)
        }
        return BoxView(
            width: .fixed(ClawdArt.width),
            height: .fixed(1),
            flexDirection: .row,
            children: children
        )
    }
}
