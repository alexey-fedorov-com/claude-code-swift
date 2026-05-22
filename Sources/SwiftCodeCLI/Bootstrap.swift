import ArgumentParser
import Foundation

// MARK: - Stub Subcommands

// MARK: server

public struct ServerCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "server",
        abstract: "Start a Swift Code session server"
    )

    @Option(name: .customLong("port"), help: "HTTP port")
    public var port: String = "0"

    @Option(name: .customLong("host"), help: "Bind address")
    public var host: String = "0.0.0.0"

    @Option(name: .customLong("auth-token"), help: "Bearer token for auth")
    public var authToken: String?

    @Option(name: .customLong("unix"), help: "Listen on a unix domain socket")
    public var unix: String?

    @Option(name: .customLong("workspace"), help: "Default working directory for sessions that do not specify cwd")
    public var workspace: String?

    @Option(name: .customLong("idle-timeout"), help: "Idle timeout for detached sessions in ms (0 = never expire)")
    public var idleTimeout: String = "600000"

    @Option(name: .customLong("max-sessions"), help: "Maximum concurrent sessions (0 = unlimited)")
    public var maxSessions: String = "32"

    public init() {}

    public mutating func run() throws {
        print("server: unimplemented")
    }
}

// MARK: ssh

public struct SSHCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "ssh",
        abstract: "Run Swift Code on a remote host over SSH. Deploys the binary and tunnels API auth back through your local machine — no remote setup needed."
    )

    @Argument(help: "Remote host")
    public var host: String

    @Argument(help: "Remote directory (optional)")
    public var dir: String?

    @Option(name: .customLong("permission-mode"), help: "Permission mode for the remote session")
    public var permissionMode: String?

    @Flag(name: .customLong("dangerously-skip-permissions"), help: "Skip all permission prompts on the remote (dangerous)")
    public var dangerouslySkipPermissions: Bool = false

    @Flag(name: .customLong("local"), help: "e2e test mode — spawn the child CLI locally (skip ssh/deploy)")
    public var local: Bool = false

    public init() {}

    public mutating func run() throws {
        print("ssh: unimplemented")
    }
}

// MARK: open

public struct OpenCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Connect to a Swift Code server (internal — use cc:// URLs)"
    )

    @Argument(help: "cc:// URL")
    public var ccUrl: String

    @Option(name: [.customShort("p"), .customLong("print")], help: "Print mode (headless)")
    public var printMode: String?

    @Option(name: .customLong("output-format"), help: "Output format: text, json, stream-json")
    public var outputFormat: String = "text"

    public init() {}

    public mutating func run() throws {
        print("open: unimplemented")
    }
}

// MARK: setup-token

public struct SetupTokenCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "setup-token",
        abstract: "Set up a long-lived authentication token (requires Claude subscription)"
    )

    public init() {}

    public mutating func run() throws {
        print("setup-token: unimplemented")
    }
}

// MARK: agents

public struct AgentsCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "agents",
        abstract: "List configured agents"
    )

    @Option(name: .customLong("setting-sources"), help: "Comma-separated list of setting sources to load (user, project, local).")
    public var settingSources: String?

    public init() {}

    public mutating func run() throws {
        print("agents: unimplemented")
    }
}

// MARK: auto-mode

public struct AutoModeCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "auto-mode",
        abstract: "Inspect auto mode classifier configuration",
        subcommands: [
            AutoModeDefaultsCommand.self,
            AutoModeConfigCommand.self,
            AutoModeCritiqueCommand.self,
        ]
    )
    public init() {}
}

public struct AutoModeDefaultsCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "defaults",
        abstract: "Print the default auto mode environment, allow, and deny rules as JSON"
    )
    public init() {}
    public mutating func run() throws {
        print("auto-mode defaults: unimplemented")
    }
}

public struct AutoModeConfigCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Print the effective auto mode config as JSON: your settings where set, defaults otherwise"
    )
    public init() {}
    public mutating func run() throws {
        print("auto-mode config: unimplemented")
    }
}

public struct AutoModeCritiqueCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "critique",
        abstract: "Get AI feedback on your custom auto mode rules"
    )

    @Option(name: .customLong("model"), help: "Override which model is used")
    public var model: String?

    public init() {}
    public mutating func run() throws {
        print("auto-mode critique: unimplemented")
    }
}

// MARK: remote-control

public struct RemoteControlCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "remote-control",
        abstract: "Start a remote-control bridge session"
    )
    public init() {}
    public mutating func run() throws {
        print("remote-control: unimplemented")
    }
}

// MARK: assistant

public struct AssistantCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "assistant",
        abstract: "Attach the REPL as a client to a running bridge session. Discovers sessions via API if no sessionId given."
    )

    @Argument(help: "Session ID (optional)")
    public var sessionId: String?

    public init() {}
    public mutating func run() throws {
        print("assistant: unimplemented")
    }
}

// MARK: doctor

public struct DoctorCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check the health of your Swift Code auto-updater. Note: The workspace trust dialog is skipped and stdio servers from .mcp.json are spawned for health checks. Only use this command in directories you trust."
    )
    public init() {}
    public mutating func run() throws {
        print("doctor: unimplemented")
    }
}

// MARK: update / upgrade

public struct UpdateCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Check for updates and install if available",
        aliases: ["upgrade"]
    )
    public init() {}
    public mutating func run() throws {
        print("update: unimplemented")
    }
}

// MARK: install

public struct InstallCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install Swift Code native build. Use [target] to specify version (stable, latest, or specific version)"
    )

    @Argument(help: "Version target (stable, latest, or specific version)")
    public var target: String?

    @Flag(name: .customLong("force"), help: "Force installation even if already installed")
    public var force: Bool = false

    public init() {}
    public mutating func run() throws {
        print("install: unimplemented")
    }
}

// MARK: task

public struct TaskCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "task",
        abstract: "[ANT-ONLY] Manage task list tasks",
        subcommands: [
            TaskCreateCommand.self,
            TaskListCommand.self,
            TaskGetCommand.self,
            TaskUpdateCommand.self,
            TaskDirCommand.self,
        ]
    )
    public init() {}
}

public struct TaskCreateCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new task"
    )

    @Argument(help: "Task subject")
    public var subject: String

    @Option(name: [.customShort("d"), .customLong("description")], help: "Task description")
    public var description: String?

    @Option(name: [.customShort("l"), .customLong("list")], help: "Task list ID (defaults to \"tasklist\")")
    public var list: String?

    public init() {}
    public mutating func run() throws {
        print("task create: unimplemented")
    }
}

public struct TaskListCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all tasks"
    )

    @Option(name: [.customShort("l"), .customLong("list")], help: "Task list ID (defaults to \"tasklist\")")
    public var list: String?

    @Flag(name: .customLong("pending"), help: "Show only pending tasks")
    public var pending: Bool = false

    @Flag(name: .customLong("json"), help: "Output as JSON")
    public var json: Bool = false

    public init() {}
    public mutating func run() throws {
        print("task list: unimplemented")
    }
}

public struct TaskGetCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get details of a task"
    )

    @Argument(help: "Task ID")
    public var id: String

    @Option(name: [.customShort("l"), .customLong("list")], help: "Task list ID (defaults to \"tasklist\")")
    public var list: String?

    public init() {}
    public mutating func run() throws {
        print("task get: unimplemented")
    }
}

public struct TaskUpdateCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update a task"
    )

    @Argument(help: "Task ID")
    public var id: String

    @Option(name: [.customShort("l"), .customLong("list")], help: "Task list ID (defaults to \"tasklist\")")
    public var list: String?

    @Option(name: [.customShort("s"), .customLong("status")], help: "Set status (pending, in_progress, completed, cancelled)")
    public var status: String?

    @Option(name: .customLong("subject"), help: "Update subject")
    public var subject: String?

    @Option(name: [.customShort("d"), .customLong("description")], help: "Update description")
    public var description: String?

    @Option(name: .customLong("owner"), help: "Set owner")
    public var owner: String?

    @Flag(name: .customLong("clear-owner"), help: "Clear owner")
    public var clearOwner: Bool = false

    public init() {}
    public mutating func run() throws {
        print("task update: unimplemented")
    }
}

public struct TaskDirCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "dir",
        abstract: "Show the tasks directory path"
    )

    @Option(name: [.customShort("l"), .customLong("list")], help: "Task list ID (defaults to \"tasklist\")")
    public var list: String?

    public init() {}
    public mutating func run() throws {
        print("task dir: unimplemented")
    }
}
