# Swift Code

Swift rewrite of Claude Code (v2.1.88). The original TypeScript reference implementation is preserved under `.reference/`.

## Requirements

- Swift 6.3+
- macOS 13+

## Build

```bash
swift build          # debug build
swift build -c release  # optimized release build
```

## Run

```bash
swift run swiftcode -- --version
swift run swiftcode -- --help
swift run swiftcode -- chat
```

## Test

```bash
swift test
```

## Release Build

Produces a self-contained binary at `dist/swiftcode`:

```bash
scripts/build-release.sh
```

Expected output: `2.1.88 (Swift Code)`

## Install Locally

Installs to `~/.local/bin/swiftcode`:

```bash
scripts/install-local.sh
```

## Parity Testing

Run CLI output comparison against the reference TypeScript build:

```bash
scripts/run-parity.sh
```

## Module Structure

| Module | Responsibility |
|---|---|
| `SwiftCode` | Top-level entry point |
| `SwiftCodeCLI` | Commander-style CLI parser, flags, subcommands |
| `SwiftCodeCore` | Types, feature flags, messages, agent state |
| `SwiftCodeAPI` | Anthropic API client, streaming, cost, retry |
| `SwiftCodeAgent` | Query loop, system prompts, context, compaction |
| `SwiftCodeTools` | 45+ built-in tools (bash, file, web, etc.) |
| `SwiftCodeCommands` | Slash commands, command registry |
| `SwiftCodePermissions` | Permission rules, shell safety classifier |
| `SwiftCodeSettings` | Settings, config, env vars, migrations |
| `SwiftCodeHooks` | Pre/post tool hooks, hook runner |
| `SwiftCodePlugins` | Plugin loader, marketplace, bundled skills |
| `SwiftCodeMCP` | MCP client/server, OAuth, tool discovery |
| `SwiftCodeLSP` | Language server protocol support |
| `SwiftCodeRemote` | Remote sessions, bridge, background agents |
| `SwiftCodeTerminalUI` | Ink-style terminal renderer, Yoga layout |
| `SwiftCodeNative` | Process, filesystem, git, secure storage |
| `SwiftCodeVim` | Vim mode, keybindings |

## What This Repo Is

This is a ground-up Swift reconstruction of Claude Code, using the leaked TypeScript source as the reference. It is not a fork and not a wrapper — it's a native Swift implementation targeting behavioral parity with the original.

The TypeScript source lives at `.reference/src/`. The build system is the Swift Package Manager.
