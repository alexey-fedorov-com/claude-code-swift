import Foundation

public enum Spinner {
    public static let dotsFrames: [String] = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    @available(*, deprecated, renamed: "dotsFrames")
    public static let brailleFrames: [String] = dotsFrames
}

public struct SpinnerView: View {
    public let frameIndex: Int
    public let color: CellColor

    public init(frameIndex: Int, color: CellColor = .rgb(215, 119, 87)) {
        self.frameIndex = frameIndex; self.color = color
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let frame = Spinner.dotsFrames[frameIndex % Spinner.dotsFrames.count]
        let yoga = YogaNode()
        yoga.text = frame
        yoga.width = .fixed(1); yoga.height = .fixed(1)
        let styleId = styles.id(for: CellStyle(fg: color))
        return LayoutNode(yoga: yoga) { screen, node in
            screen.write(text: frame, at: node.yoga.layoutX, row: node.yoga.layoutY, styleId: styleId)
        }
    }
}

// MARK: - Legacy spinner type

@available(*, deprecated, message: "Use SpinnerView for View-protocol-based rendering")
public struct LegacySpinner {
    public static let brailleFrames: [String] = Spinner.dotsFrames
    public static let dotFrames: [String] = ["|", "/", "-", "\\"]

    public let frames: [String]
    public let label: String?
    public let color: ANSIColor?
    public let bold: Bool

    public init(
        label: String? = nil,
        frames: [String] = LegacySpinner.brailleFrames,
        color: ANSIColor? = nil,
        bold: Bool = false
    ) {
        self.frames = frames
        self.label = label
        self.color = color
        self.bold = bold
    }

    public func currentText(frame: Int) -> String {
        let f = frames[frame % frames.count]
        if let label = label {
            return "\(f) \(label)"
        }
        return f
    }

    public func buildNode(frame: Int) -> YogaNode {
        let node = YogaNode()
        node.text = currentText(frame: frame)
        node.width = .auto
        node.height = .auto
        return node
    }

    public func buildRenderNode(from yogaNode: YogaNode, frame: Int) -> RenderNode {
        let attrs = TextAttributes(color: color, bold: bold)
        return .text(
            x: yogaNode.layoutX, y: yogaNode.layoutY,
            width: yogaNode.layoutWidth, height: yogaNode.layoutHeight,
            content: currentText(frame: frame),
            attributes: attrs
        )
    }

    public static func animate(
        interval: TimeInterval = 0.08,
        onFrame: @escaping @Sendable (Int) -> Void
    ) -> @Sendable () -> Void {
        final class State: @unchecked Sendable {
            var frame: Int = 0
            var running: Bool = true
        }
        let state = State()
        let thread = Thread {
            while state.running {
                onFrame(state.frame)
                state.frame += 1
                Thread.sleep(forTimeInterval: interval)
            }
        }
        thread.start()
        return { state.running = false }
    }
}
