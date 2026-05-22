import Foundation

/// Spinner component with animated braille frames and an optional label.
public struct Spinner {
    /// Classic braille spinner (10 frames, ~80ms each for smooth animation).
    public static let brailleFrames: [String] = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    /// Dot-based spinner (simpler, for terminals without Unicode support).
    public static let dotFrames: [String] = ["|", "/", "-", "\\"]

    public let frames: [String]
    public let label: String?
    public let color: ANSIColor?
    public let bold: Bool

    public init(
        label: String? = nil,
        frames: [String] = Spinner.brailleFrames,
        color: ANSIColor? = nil,
        bold: Bool = false
    ) {
        self.frames = frames
        self.label = label
        self.color = color
        self.bold = bold
    }

    // MARK: - Current frame

    /// Returns the current frame string (spinner + optional label).
    public func currentText(frame: Int) -> String {
        let f = frames[frame % frames.count]
        if let label = label {
            return "\(f) \(label)"
        }
        return f
    }

    // MARK: - Build node

    /// Build a YogaNode for the current animation frame.
    public func buildNode(frame: Int) -> YogaNode {
        let node = YogaNode()
        node.text = currentText(frame: frame)
        node.width = .auto
        node.height = .auto
        return node
    }

    /// Build a RenderNode from a laid-out yoga node.
    public func buildRenderNode(from yogaNode: YogaNode, frame: Int) -> RenderNode {
        let attrs = TextAttributes(
            color: color, bold: bold
        )
        return .text(
            x: yogaNode.layoutX, y: yogaNode.layoutY,
            width: yogaNode.layoutWidth, height: yogaNode.layoutHeight,
            content: currentText(frame: frame),
            attributes: attrs
        )
    }

    // MARK: - Simple drive loop (for demo use; real usage drives frame externally)

    /// Returns a timer-based sequence of frame indices using a callback.
    /// - Parameters:
    ///   - interval: Seconds per frame.
    ///   - onFrame: Called with the current frame index.
    ///   - stop: Call this to stop the animation.
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
