/// BashTool — execute shell commands via /bin/bash.
///
/// Reference: .reference/src/tools/BashTool/BashTool.tsx
/// Timeout default: 120s (matches reference BASH_DEFAULT_TIMEOUT_MS = 120_000).
/// MAX_EDIT_FILE_SIZE (1 GiB) guard is on file tools; Bash has no output size limit at this layer.

import Foundation
import SwiftCodeCore
import SwiftCodeNative
import SwiftCodePermissions

// MARK: - BashTool

public struct BashTool: ToolHandler {
    public let name = "Bash"
    public let description = """
        Executes a given bash command in a persistent shell session with optional \
        timeout, ensuring proper handling and security measures.
        """

    public let inputSchema = ToolInputSchema(
        properties: [
            "command": PropertySchema(
                type: "string",
                description: "The bash command to execute. Required unless the tool is being called to restart the shell."
            ),
            "timeout": PropertySchema(
                type: "integer",
                description: "Optional timeout in milliseconds (max 600000)."
            ),
            "description": PropertySchema(
                type: "string",
                description: "Clear, concise description of what this command does in active voice."
            )
        ],
        required: ["command"]
    )

    private let runner: ProcessRunner

    public init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    public func execute(input: [String: JSONValue]) async throws -> String {
        guard let command = input["command"]?.stringValue else {
            throw ToolError.invalidInput(tool: name, message: "command is required")
        }

        // Timeout: input milliseconds → TimeInterval seconds. Capped at 600s.
        let timeoutMs = input["timeout"]?.intValue ?? 120_000
        let cappedMs = min(timeoutMs, 600_000)
        let timeout = TimeInterval(cappedMs) / 1000.0

        let result = try await runner.run(
            executable: "/bin/bash",
            arguments: ["-c", command],
            timeout: timeout
        )

        // Combine stdout + stderr in the same way the reference does
        var output = result.stdout
        if !result.stderr.isEmpty {
            if !output.isEmpty { output += "\n" }
            output += result.stderr
        }

        // Return output; non-zero exit is surfaced inline so the model can react.
        if result.exitCode != 0 && output.isEmpty {
            output = "Process exited with code \(result.exitCode)"
        }
        return output.isEmpty ? "(no output)" : output
    }
}
