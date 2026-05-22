import ArgumentParser
import Foundation

public struct SwiftCodeCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "swiftcode",
        abstract: "Swift Code - starts an interactive session by default, use -p/--print for non-interactive output",
        version: "2.1.88"
    )

    @Argument(help: "Your prompt")
    public var prompt: String?

    @Flag(name: [.short, .customLong("print")], help: "Print response and exit (useful for pipes). Note: The workspace trust dialog is skipped when Swift Code is run with the -p mode. Only use this flag in directories you trust.")
    public var printMode = false

    public init() {}

    public mutating func run() async throws {
        if printMode {
            FileHandle.standardOutput.write(Data("Swift rewrite scaffold\n".utf8))
        } else {
            FileHandle.standardOutput.write(Data("Swift rewrite scaffold\n".utf8))
        }
    }

    // Explicit async entry point to avoid overload ambiguity with ParsableCommand.main()
    public static func _runAsync() async {
        await Self.main()
    }
}
