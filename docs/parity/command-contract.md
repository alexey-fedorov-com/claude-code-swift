# Command Contract — Slash Command Parity

This document records the behavioral contract between the TypeScript reference implementation and the Swift port for slash commands.

## Reference

- TypeScript: `.reference/src/commands.ts`, `.reference/src/commands/*/`
- Swift: `Sources/SwiftCodeCommands/`

## Protocol

Every slash command conforms to `SlashCommand` (see `SlashCommand.swift`):

```swift
public protocol SlashCommand: Sendable {
    var name: String { get }               // primary name, no leading "/"
    var description: String { get }        // shown in /help
    var aliases: [String] { get }          // alternative names
    var isHidden: Bool { get }             // omit from /help listings
    var requiresAntUser: Bool { get }      // ant-only: suppress for external users
    var requiredFeatureFlag: FeatureFlag? { get }  // nil = always available
    var supportsNonInteractive: Bool { get }

    func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult
}
```

## Result Types

| Case | Behavior |
|------|----------|
| `.message(String)` | Print text to the terminal |
| `.promptInjection(String)` | Inject into the next user message sent to the model |
| `.exit(Int32)` | Exit the process with the given code |
| `.noop` | Silent — do nothing |
| `.clearContext` | Clear the conversation transcript |
| `.setModel(String)` | Switch the active model (alias or canonical ID) |

## Availability Rules (mirrors commands.ts)

1. `requiresAntUser == true` AND `(antUser == false OR demoMode == true)` → hidden
2. `requiredFeatureFlag != nil` AND flag is disabled → hidden
3. `isHidden == true` → omitted from `/help` listings but still callable

## Fully Implemented Commands (8)

| Command | Key behavior |
|---------|--------------|
| `/help` | Lists all visible commands with name/description/aliases |
| `/clear` | Returns `.clearContext` |
| `/exit` | Returns `.exit(0)`; aliases: `quit`, `q` |
| `/model [alias]` | No arg → print current model; with arg → `.setModel(id)` or error |
| `/config [key val]` | No arg → print key settings; with args → scaffold for settings write |
| `/cost` | Reads `CostTracker` from context; prints USD total + per-model breakdown |
| `/status` | Prints CWD, model, session ID, user type, active feature flags |
| `/vim` | Returns `.promptInjection("__VIM_TOGGLE__")` for REPL to intercept |

## Stub Commands (~75)

All other commands return `.message("Command '<name>' is not yet implemented in Swift Code.")`.
Each stub correctly sets `requiresAntUser` and `requiredFeatureFlag` so availability filtering
works correctly even without a full implementation.

## Registry

`CommandRegistry` is a Swift `actor`. Key API:

```swift
public actor CommandRegistry {
    public func register(_ command: any SlashCommand)
    public func lookup(name: String) -> (any SlashCommand)?
    public func availableCommands(antUser: Bool, demoMode: Bool) -> [any SlashCommand]
    public static let allCommandNames: [String]  // 80+ entries
    public static func defaultRegistry() -> CommandRegistry
}
```

`defaultRegistry()` registers commands in the same order as `COMMANDS()` in the reference.

## Extension Points (Tasks 16/17)

- Dynamic skill commands from skill directories → `register(_:)` at startup
- Plugin commands → same
- Workflow commands → same (feature-gated via `.workflowScripts`)

## Test Coverage

| Test File | Coverage |
|-----------|----------|
| `CommandRegistryTests.swift` | register, lookup, alias lookup, availability filtering, allCommandNames |
| `CommandParityTests.swift` | all 80+ names present, minimum count, 8 core commands registered |
| `HelpCommandTests.swift` | output format, visibility, ant-user filtering |
| `ClearCommandTests.swift` | `.clearContext` result |
| `ExitCommandTests.swift` | `.exit(0)` result, aliases |
| `ModelCommandTests.swift` | no-arg print, valid alias → `.setModel`, unknown → error |
| `CostCommandTests.swift` | no tracker → $0.00, with tracker → breakdown |
| `StatusCommandTests.swift` | CWD in output, user type labels |
| `VimCommandTests.swift` | sentinel value, `.promptInjection` result |
