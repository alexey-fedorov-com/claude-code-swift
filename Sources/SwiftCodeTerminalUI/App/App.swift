import Foundation

public protocol AppIO: Sendable {
    func write(_ bytes: String) async
}

public struct FileHandleIO: AppIO {
    public init() {}
    public func write(_ bytes: String) async {
        FileHandle.standardOutput.write(Data(bytes.utf8))
    }
}

public actor App<State: Sendable> {
    private var state: State
    private let viewFn: @Sendable (State) -> any View
    private let updateFn: @Sendable (InputEvent, inout State) -> Void
    private let io: any AppIO
    private var width: Int
    private var height: Int
    private var theme: Theme = .default
    private var styles = CellStyleTable()
    private var previousScreen: Screen?
    private var spinnerFrame = 0

    public init(initialState: State,
                view: @escaping @Sendable (State) -> any View,
                update: @escaping @Sendable (InputEvent, inout State) -> Void,
                io: any AppIO,
                width: Int, height: Int) {
        self.state = initialState
        self.viewFn = view
        self.updateFn = update
        self.io = io
        self.width = width
        self.height = height
    }

    public func renderInitialFrame() async {
        let next = renderScreen()
        let out = ScreenDiff.computeInitial(next: next, styles: styles)
        await io.write(out)
        previousScreen = next
    }

    public func renderFrameIfNeeded() async {
        let next = renderScreen()
        let out: String
        if let prev = previousScreen, prev.width == next.width, prev.height == next.height {
            out = ScreenDiff.compute(prev: prev, next: next, styles: styles)
        } else {
            out = ScreenDiff.computeInitial(next: next, styles: styles)
        }
        if !out.isEmpty { await io.write(out) }
        previousScreen = next
    }

    public func dispatch(_ event: InputEvent) {
        switch event {
        case .resize(let w, let h):
            self.width = w
            self.height = h
            self.previousScreen = nil  // force full repaint
        default:
            updateFn(event, &state)
        }
    }

    public func withState(_ body: @Sendable (inout State) -> Void) {
        body(&state)
    }

    public func tickSpinner() { spinnerFrame &+= 1 }
    public func currentSpinnerFrame() -> Int { spinnerFrame }

    private func renderScreen() -> Screen {
        let view = viewFn(state)
        let root = view.buildLayoutNode(theme: theme, styles: styles)
        YogaCalculator().calculate(root: root.yoga, availableWidth: width, availableHeight: height)
        var screen = Screen(width: width, height: height)
        paint(node: root, into: &screen)
        return screen
    }
}
