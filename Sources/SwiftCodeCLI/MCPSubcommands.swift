import ArgumentParser
import Foundation

// MARK: - MCP Command

public struct MCPCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Configure and manage MCP servers",
        subcommands: [
            MCPAddCommand.self,
            MCPAddJSONCommand.self,
            MCPAddFromClaudeDesktopCommand.self,
            MCPRemoveCommand.self,
            MCPListCommand.self,
            MCPGetCommand.self,
            MCPResetProjectChoicesCommand.self,
            MCPServeCommand.self,
        ]
    )
    public init() {}
}

// MARK: - mcp add

public struct MCPAddCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: """
            Add an MCP server to Swift Code.

            Examples:
              # Add HTTP server:
              swiftcode mcp add --transport http sentry https://mcp.sentry.dev/mcp

              # Add HTTP server with headers:
              swiftcode mcp add --transport http corridor https://app.corridor.dev/api/mcp --header "Authorization: Bearer ..."

              # Add stdio server with environment variables:
              swiftcode mcp add -e API_KEY=xxx my-server -- npx my-mcp-server

              # Add stdio server with subprocess flags:
              swiftcode mcp add my-server -- my-command --some-flag arg1
            """
    )

    @Argument(help: "Server name")
    public var name: String

    @Argument(help: "Command or URL")
    public var commandOrUrl: String

    @Argument(help: "Additional arguments")
    public var args: [String] = []

    @Option(name: [.customShort("s"), .customLong("scope")], help: "Configuration scope (local, user, or project)")
    public var scope: String = "local"

    @Option(name: [.customShort("t"), .customLong("transport")], help: "Transport type (stdio, sse, http). Defaults to stdio if not specified.")
    public var transport: String?

    @Option(name: [.customShort("e"), .customLong("env")], parsing: .upToNextOption, help: "Set environment variables (e.g. -e KEY=value)")
    public var env: [String] = []

    @Option(name: [.customShort("H"), .customLong("header")], parsing: .upToNextOption, help: "Set WebSocket headers (e.g. -H \"X-Api-Key: abc123\")")
    public var header: [String] = []

    @Option(name: .customLong("client-id"), help: "OAuth client ID for HTTP/SSE servers")
    public var clientId: String?

    @Flag(name: .customLong("client-secret"), help: "Prompt for OAuth client secret (or set MCP_CLIENT_SECRET env var)")
    public var clientSecret: Bool = false

    @Option(name: .customLong("callback-port"), help: "Fixed port for OAuth callback")
    public var callbackPort: String?

    public init() {}

    public mutating func run() throws {
        print("mcp add: unimplemented")
    }
}

// MARK: - mcp add-json

public struct MCPAddJSONCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "add-json",
        abstract: "Add an MCP server (stdio or SSE) with a JSON string"
    )

    @Argument(help: "Server name")
    public var name: String

    @Argument(help: "JSON configuration string")
    public var json: String

    @Option(name: [.customShort("s"), .customLong("scope")], help: "Configuration scope (local, user, or project)")
    public var scope: String = "local"

    @Flag(name: .customLong("client-secret"), help: "Prompt for OAuth client secret (or set MCP_CLIENT_SECRET env var)")
    public var clientSecret: Bool = false

    public init() {}

    public mutating func run() throws {
        print("mcp add-json: unimplemented")
    }
}

// MARK: - mcp add-from-claude-desktop

public struct MCPAddFromClaudeDesktopCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "add-from-claude-desktop",
        abstract: "Import MCP servers from Claude Desktop (Mac and WSL only)"
    )

    @Option(name: [.customShort("s"), .customLong("scope")], help: "Configuration scope (local, user, or project)")
    public var scope: String = "local"

    public init() {}

    public mutating func run() throws {
        print("mcp add-from-claude-desktop: unimplemented")
    }
}

// MARK: - mcp remove

public struct MCPRemoveCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove an MCP server"
    )

    @Argument(help: "Server name")
    public var name: String

    @Option(name: [.customShort("s"), .customLong("scope")], help: "Configuration scope (local, user, or project) - if not specified, removes from whichever scope it exists in")
    public var scope: String?

    public init() {}

    public mutating func run() throws {
        print("mcp remove: unimplemented")
    }
}

// MARK: - mcp list

public struct MCPListCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List configured MCP servers. Note: The workspace trust dialog is skipped and stdio servers from .mcp.json are spawned for health checks. Only use this command in directories you trust."
    )

    public init() {}

    public mutating func run() throws {
        print("mcp list: unimplemented")
    }
}

// MARK: - mcp get

public struct MCPGetCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get details about an MCP server. Note: The workspace trust dialog is skipped and stdio servers from .mcp.json are spawned for health checks. Only use this command in directories you trust."
    )

    @Argument(help: "Server name")
    public var name: String

    public init() {}

    public mutating func run() throws {
        print("mcp get: unimplemented")
    }
}

// MARK: - mcp reset-project-choices

public struct MCPResetProjectChoicesCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "reset-project-choices",
        abstract: "Reset all approved and rejected project-scoped (.mcp.json) servers within this project"
    )

    public init() {}

    public mutating func run() throws {
        print("mcp reset-project-choices: unimplemented")
    }
}

// MARK: - mcp serve

public struct MCPServeCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Start the Swift Code MCP server"
    )

    @Flag(name: [.customShort("d"), .customLong("debug")], help: "Enable debug mode")
    public var debug: Bool = false

    @Flag(name: .customLong("verbose"), help: "Override verbose mode setting from config")
    public var verbose: Bool = false

    public init() {}

    public mutating func run() throws {
        print("mcp serve: unimplemented")
    }
}
