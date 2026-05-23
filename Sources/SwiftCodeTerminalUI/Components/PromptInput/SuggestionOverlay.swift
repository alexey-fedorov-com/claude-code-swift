// MARK: - PathSuggestion

/// A file/directory suggestion item (wired in Task 13).
public struct PathSuggestion: Sendable, Equatable {
    public let display: String
    public let isDirectory: Bool
    public init(display: String, isDirectory: Bool) {
        self.display = display
        self.isDirectory = isDirectory
    }
}

// MARK: - SuggestionItem

/// A single item shown in the autocomplete overlay.
public enum SuggestionItem: Sendable, Equatable {
    case command(CommandSuggestion)
    case path(PathSuggestion)  // wired in Task 13
}

// MARK: - SuggestionOverlay

/// A View that renders the autocomplete dropdown beneath PromptInput.
/// When `items` is empty the view produces zero height.
public struct SuggestionOverlay: View {
    public let items: [SuggestionItem]
    public let selectedIndex: Int
    public let width: Int
    public let maxVisible: Int

    public init(items: [SuggestionItem],
                selectedIndex: Int,
                width: Int,
                maxVisible: Int = 6) {
        self.items = items
        self.selectedIndex = selectedIndex
        self.width = width
        self.maxVisible = maxVisible
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        guard !items.isEmpty else {
            return BoxView(width: .fixed(width), height: .fixed(0))
                .buildLayoutNode(theme: theme, styles: styles)
        }

        let visible = Array(items.prefix(maxVisible))
        var rows: [any View] = visible.enumerated().map { idx, item in
            row(item: item, selected: idx == selectedIndex, theme: theme)
        }
        if items.count > maxVisible {
            rows.append(TextView("+\(items.count - maxVisible) more", dim: true))
        }

        return BoxView(
            width: .fixed(width),
            padding: EdgeInsets(horizontal: 1),
            border: .rounded,
            borderColor: .ansi256(240),
            flexDirection: .column,
            children: rows
        ).buildLayoutNode(theme: theme, styles: styles)
    }

    // MARK: - Private

    private func row(item: SuggestionItem, selected: Bool, theme: Theme) -> any View {
        let (lhs, rhs): (String, String)
        switch item {
        case .command(let c):
            lhs = "/\(c.name)"
            rhs = c.description
        case .path(let p):
            lhs = p.display
            rhs = p.isDirectory ? "directory" : "file"
        }
        return BoxView(width: .auto, flexDirection: .row, children: [
            TextView(selected ? "> " : "  ", color: selected ? theme.claude : .default),
            TextView(lhs, color: selected ? theme.claude : .default),
            TextView("  "),
            TextView(rhs, dim: true),
        ])
    }
}
