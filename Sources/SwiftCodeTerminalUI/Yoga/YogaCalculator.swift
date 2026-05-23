/// Two-pass layout calculator.
/// Pass 1 (measureWidth): resolves widths top-down (parent passes available width to children).
/// Pass 2 (measureHeight + position): resolves heights and positions bottom-up.
public struct YogaCalculator {

    public init() {}

    /// Entry point: compute layout for the tree rooted at `root`.
    /// `availableWidth` and `availableHeight` represent the terminal/container dimensions.
    public func calculate(root: YogaNode, availableWidth: Int, availableHeight: Int) {
        root.layoutX = 0
        root.layoutY = 0
        measureWidth(node: root, availableWidth: availableWidth)
        measureHeight(node: root, availableHeight: availableHeight)
        positionChildren(node: root, originX: 0, originY: 0)
    }

    // MARK: - Width pass

    private func measureWidth(node: YogaNode, availableWidth: Int) {
        // display:none → zero out and skip recursion
        if node.display == .none {
            node.layoutWidth = 0
            node.layoutHeight = 0
            return
        }

        let resolvedWidth: Int
        switch node.width {
        case .fixed(let w):
            resolvedWidth = w
        case .percent(let p):
            resolvedWidth = Int(Double(availableWidth) * p)
        case .auto:
            resolvedWidth = availableWidth
        }

        let clamped = clamp(resolvedWidth, min: node.minWidth, max: node.maxWidth)
        node.layoutWidth = clamped

        let innerWidth = max(0, clamped - node.padding.horizontal)

        if node.children.isEmpty {
            // Text node: width is natural text width if auto, else already set
            if case .auto = node.width, let text = node.text {
                node.layoutWidth = textWidth(text) + node.padding.horizontal
            }
        } else {
            // Recurse into children
            for child in node.children {
                let childAvailable: Int
                switch node.flexDirection {
                case .row:
                    // In a row, each child gets the full inner width (we'll split later)
                    childAvailable = innerWidth
                case .column:
                    childAvailable = innerWidth
                }
                measureWidth(node: child, availableWidth: max(0, childAvailable - child.margin.horizontal))
            }

            // For row direction with .auto width, sum up children widths
            if case .auto = node.width, node.flexDirection == .row {
                let visibleChildren = node.children.filter { $0.display != .none }
                let childrenTotal = visibleChildren.reduce(0) { $0 + $1.layoutWidth + $1.margin.horizontal }
                node.layoutWidth = childrenTotal + node.padding.horizontal
            }
        }
    }

    // MARK: - Height pass

    private func measureHeight(node: YogaNode, availableHeight: Int) {
        // display:none → zero out and skip recursion (width already zeroed in measureWidth)
        if node.display == .none {
            node.layoutWidth = 0
            node.layoutHeight = 0
            return
        }

        let resolvedHeight: Int
        switch node.height {
        case .fixed(let h):
            resolvedHeight = h
        case .percent(let p):
            resolvedHeight = Int(Double(availableHeight) * p)
        case .auto:
            resolvedHeight = availableHeight
        }
        node.layoutHeight = resolvedHeight

        if node.children.isEmpty {
            // Text node
            if case .auto = node.height, let text = node.text {
                let lines = text.components(separatedBy: "\n").count
                node.layoutHeight = lines + node.padding.vertical
            } else if case .auto = node.height {
                node.layoutHeight = 1 + node.padding.vertical
            }
        } else {
            let innerHeight = max(0, resolvedHeight - node.padding.vertical)
            for child in node.children {
                let childAvailable: Int
                switch node.flexDirection {
                case .column:
                    childAvailable = innerHeight
                case .row:
                    childAvailable = innerHeight
                }
                measureHeight(node: child, availableHeight: max(0, childAvailable - child.margin.vertical))
            }

            // Auto height: sum children in column, max in row (skip display:none)
            if case .auto = node.height {
                let visibleChildren = node.children.filter { $0.display != .none }
                switch node.flexDirection {
                case .column:
                    let childrenTotal = visibleChildren.reduce(0) { $0 + $1.layoutHeight + $1.margin.vertical }
                    let gapTotal = visibleChildren.count > 1 ? node.gap * (visibleChildren.count - 1) : 0
                    node.layoutHeight = childrenTotal + gapTotal + node.padding.vertical
                case .row:
                    let maxChild = visibleChildren.map { $0.layoutHeight + $0.margin.vertical }.max() ?? 0
                    node.layoutHeight = maxChild + node.padding.vertical
                }
            }
        }
    }

    // MARK: - Position pass

    private func positionChildren(node: YogaNode, originX: Int, originY: Int) {
        node.layoutX = originX + node.margin.left
        node.layoutY = originY + node.margin.top

        guard !node.children.isEmpty else { return }

        let innerX = node.layoutX + node.padding.left
        let innerY = node.layoutY + node.padding.top
        let innerWidth = max(0, node.layoutWidth - node.padding.horizontal)
        let innerHeight = max(0, node.layoutHeight - node.padding.vertical)

        switch node.flexDirection {
        case .column:
            layoutColumn(children: node.children, innerX: innerX, innerY: innerY,
                         innerWidth: innerWidth, innerHeight: innerHeight,
                         justify: node.justifyContent, align: node.alignItems,
                         gap: node.gap)
        case .row:
            layoutRow(children: node.children, innerX: innerX, innerY: innerY,
                      innerWidth: innerWidth, innerHeight: innerHeight,
                      justify: node.justifyContent, align: node.alignItems,
                      gap: node.gap)
        }

        // Recurse (including display:none children so they get positioned at 0,0 consistently)
        for child in node.children {
            positionChildren(node: child, originX: child.layoutX - child.margin.left,
                             originY: child.layoutY - child.margin.top)
        }
    }

    private func layoutColumn(children: [YogaNode], innerX: Int, innerY: Int,
                               innerWidth: Int, innerHeight: Int,
                               justify: JustifyContent, align: AlignItems,
                               gap: Int) {
        let visible = children.filter { $0.display != .none }
        let gapTotal = visible.count > 1 ? gap * (visible.count - 1) : 0
        // Zero out auto-height children that will be sized by flexGrow so freeSpace is computed correctly
        for child in visible where child.flexGrow > 0 {
            if case .auto = child.height { child.layoutHeight = 0 }
        }
        let totalChildHeight = visible.reduce(0) { $0 + $1.layoutHeight + $1.margin.vertical }
        var freeSpace = max(0, innerHeight - totalChildHeight - gapTotal)

        // Distribute freeSpace via flexGrow before justify-content offsets
        let totalGrow = visible.reduce(0.0) { $0 + $1.flexGrow }
        if totalGrow > 0 && freeSpace > 0 {
            var distributed = 0
            // Sort by flexGrow descending so largest gets the remainder
            let sorted = visible.sorted { $0.flexGrow > $1.flexGrow }
            for (idx, child) in sorted.enumerated() {
                let share: Int
                if idx == sorted.count - 1 {
                    share = freeSpace - distributed
                } else {
                    share = Int(Double(freeSpace) * child.flexGrow / totalGrow)
                }
                child.layoutHeight += share
                distributed += share
            }
            freeSpace = 0
        }

        let offsets: [Int] = computeOffsets(count: visible.count, freeSpace: freeSpace,
                                            justify: justify)

        var cursor = innerY
        var visibleIndex = 0
        for child in children {
            guard child.display != .none else { continue }
            cursor += offsets[visibleIndex]
            if visibleIndex > 0 { cursor += gap }
            // Resolve effective align (alignSelf overrides parent alignItems)
            let effectiveAlign = resolvedAlign(childSelf: child.alignSelf, parentAlign: align)
            // Align items (cross axis = X in column)
            let alignedX: Int
            switch effectiveAlign {
            case .start:
                alignedX = innerX + child.margin.left
            case .center:
                alignedX = innerX + max(0, (innerWidth - child.layoutWidth) / 2) + child.margin.left
            case .end:
                alignedX = innerX + max(0, innerWidth - child.layoutWidth - child.margin.right)
            case .stretch:
                alignedX = innerX + child.margin.left
            }
            child.layoutX = alignedX
            child.layoutY = cursor + child.margin.top
            cursor += child.layoutHeight + child.margin.vertical
            visibleIndex += 1
        }
    }

    private func layoutRow(children: [YogaNode], innerX: Int, innerY: Int,
                            innerWidth: Int, innerHeight: Int,
                            justify: JustifyContent, align: AlignItems,
                            gap: Int) {
        let visible = children.filter { $0.display != .none }
        let gapTotal = visible.count > 1 ? gap * (visible.count - 1) : 0
        // Zero out auto-width children that will be sized by flexGrow so freeSpace is computed correctly
        for child in visible where child.flexGrow > 0 {
            if case .auto = child.width { child.layoutWidth = 0 }
        }
        let totalChildWidth = visible.reduce(0) { $0 + $1.layoutWidth + $1.margin.horizontal }
        var freeSpace = max(0, innerWidth - totalChildWidth - gapTotal)

        // Distribute freeSpace via flexGrow before justify-content offsets
        let totalGrow = visible.reduce(0.0) { $0 + $1.flexGrow }
        if totalGrow > 0 && freeSpace > 0 {
            var distributed = 0
            // Sort by flexGrow descending so largest gets the remainder
            let sorted = visible.sorted { $0.flexGrow > $1.flexGrow }
            for (idx, child) in sorted.enumerated() {
                let share: Int
                if idx == sorted.count - 1 {
                    share = freeSpace - distributed
                } else {
                    share = Int(Double(freeSpace) * child.flexGrow / totalGrow)
                }
                child.layoutWidth += share
                distributed += share
            }
            freeSpace = 0
        }

        let offsets: [Int] = computeOffsets(count: visible.count, freeSpace: freeSpace,
                                             justify: justify)

        var cursor = innerX
        var visibleIndex = 0
        for child in children {
            guard child.display != .none else { continue }
            cursor += offsets[visibleIndex]
            if visibleIndex > 0 { cursor += gap }
            // Resolve effective align (alignSelf overrides parent alignItems)
            let effectiveAlign = resolvedAlign(childSelf: child.alignSelf, parentAlign: align)
            // Align items (cross axis = Y in row)
            let alignedY: Int
            switch effectiveAlign {
            case .start:
                alignedY = innerY + child.margin.top
            case .center:
                alignedY = innerY + max(0, (innerHeight - child.layoutHeight) / 2) + child.margin.top
            case .end:
                alignedY = innerY + max(0, innerHeight - child.layoutHeight - child.margin.bottom)
            case .stretch:
                alignedY = innerY + child.margin.top
            }
            child.layoutX = cursor + child.margin.left
            child.layoutY = alignedY
            cursor += child.layoutWidth + child.margin.horizontal
            visibleIndex += 1
        }
    }

    /// Resolve effective cross-axis alignment for a child, honoring alignSelf over parent's alignItems.
    private func resolvedAlign(childSelf: AlignSelf, parentAlign: AlignItems) -> AlignItems {
        switch childSelf {
        case .auto:   return parentAlign
        case .start:  return .start
        case .center: return .center
        case .end:    return .end
        case .stretch: return .stretch
        }
    }

    /// Returns the leading offset to insert before each child for the given justify-content.
    private func computeOffsets(count: Int, freeSpace: Int, justify: JustifyContent) -> [Int] {
        guard count > 0 else { return [] }
        var offsets = Array(repeating: 0, count: count)
        switch justify {
        case .start:
            break
        case .end:
            offsets[0] = freeSpace
        case .center:
            offsets[0] = freeSpace / 2
        case .spaceBetween:
            if count > 1 {
                let gap = freeSpace / (count - 1)
                let remainder = freeSpace % (count - 1)
                for i in 1..<count {
                    offsets[i] = gap + (i <= remainder ? 1 : 0)
                }
            }
        case .spaceAround:
            let gap = count > 0 ? freeSpace / count : 0
            for i in 0..<count {
                offsets[i] = i == 0 ? gap / 2 : gap
            }
        }
        return offsets
    }

    // MARK: - Helpers

    private func textWidth(_ text: String) -> Int {
        // Use the max line width for multi-line text
        text.components(separatedBy: "\n")
            .map { $0.count }
            .max() ?? 0
    }

    private func clamp(_ value: Int, min minVal: Int?, max maxVal: Int?) -> Int {
        var v = value
        if let mn = minVal { v = Swift.max(v, mn) }
        if let mx = maxVal { v = Swift.min(v, mx) }
        return v
    }
}
