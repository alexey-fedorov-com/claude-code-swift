#!/usr/bin/env swift
import Foundation

struct CommandCase {
    let name: String
    let args: [String]
}

let cases: [CommandCase] = [
    .init(name: "version", args: ["--version"]),
    .init(name: "short_version", args: ["-v"]),
    .init(name: "help", args: ["--help"]),
    .init(name: "mcp_help", args: ["mcp", "--help"]),
    .init(name: "auth_help", args: ["auth", "--help"]),
    .init(name: "plugin_help", args: ["plugin", "--help"]),
    .init(name: "completion_help", args: ["completion", "--help"]),
    .init(name: "print_empty", args: ["-p", ""]),
    .init(name: "dump_system_prompt", args: ["--dump-system-prompt"])
]

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let binary = root.appendingPathComponent(".build/debug/swiftcode").path
let golden = root.appendingPathComponent("Tests/Golden/cli")

func run(_ args: [String]) throws -> (Int32, String, String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: binary)
    process.arguments = args
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()
    return (
        process.terminationStatus,
        String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
        String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    )
}

func normalizeIntentionalRebrand(_ text: String) -> String {
    let productRenamed = text.replacingOccurrences(of: "Claude Code", with: "Swift Code")
    let pattern = #"(?<![A-Za-z0-9_.-])claude(?![A-Za-z0-9_.-])"#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(productRenamed.startIndex..<productRenamed.endIndex, in: productRenamed)
    return regex.stringByReplacingMatches(in: productRenamed, range: range, withTemplate: "swiftcode")
}

var failures: [String] = []
for item in cases {
    let expectedExit = try String(contentsOf: golden.appendingPathComponent("\(item.name).exit")).trimmingCharacters(in: .whitespacesAndNewlines)
    let expectedStdout = normalizeIntentionalRebrand(try String(contentsOf: golden.appendingPathComponent("\(item.name).stdout")))
    let expectedStderr = normalizeIntentionalRebrand(try String(contentsOf: golden.appendingPathComponent("\(item.name).stderr")))
    let actual = try run(item.args)
    if "\(actual.0)" != expectedExit { failures.append("\(item.name): exit \(actual.0) != \(expectedExit)") }
    if actual.1 != expectedStdout { failures.append("\(item.name): stdout differs") }
    if actual.2 != expectedStderr { failures.append("\(item.name): stderr differs") }
}

if failures.isEmpty {
    print("CLI parity passed")
} else {
    for failure in failures { FileHandle.standardError.write(Data("\(failure)\n".utf8)) }
    exit(1)
}
