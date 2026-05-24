#!/usr/bin/env python3
"""
One-off script to generate bulk source-map rows for docs/rewrite/source-map.tsv.
Reads Tests/Golden/reference-files.txt, skips already-seeded paths, emits TSV rows.
"""
import sys
import os
import re

SEED_PATHS = {
    ".reference/.gitignore",
    ".reference/CLAUDE.md",
    ".reference/README.md",
    ".reference/package.json",
    ".reference/build.ts",
    ".reference/bun.lock",
    ".reference/tsconfig.json",
    ".reference/biome.json",
    ".reference/shims/bun-bundle.ts",
    ".reference/shims/bun-bundle.d.ts",
    ".reference/src/main.tsx",
    ".reference/src/entrypoints/cli.tsx",
    ".reference/src/commands.ts",
    ".reference/src/tools.ts",
    ".reference/src/Tool.ts",
    ".reference/src/QueryEngine.ts",
    ".reference/src/query.ts",
    ".reference/src/screens/REPL.tsx",
}

# The 27 stub files documented in CLAUDE.md
STUB_PATHS = {
    ".reference/src/cli/bg.ts",
    ".reference/src/services/compact/cachedMicrocompact.ts",
    ".reference/src/services/compact/snipCompact.ts",
    ".reference/src/services/contextCollapse/index.ts",
    ".reference/src/types/connectorText.ts",
    ".reference/src/tools/REPLTool/REPLTool.ts",
    ".reference/src/tools/TungstenTool/TungstenLiveMonitor.tsx",
    ".reference/src/tools/TungstenTool/TungstenTool.ts",
    ".reference/src/tools/WorkflowTool/constants.ts",
    ".reference/src/tools/SuggestBackgroundPRTool/SuggestBackgroundPRTool.ts",
    ".reference/src/tools/VerifyPlanExecutionTool/VerifyPlanExecutionTool.ts",
    ".reference/src/moreright/useMoreRight.tsx",
    ".reference/src/ink/devtools.ts",
    ".reference/src/commands/agents-platform/index.ts",
    ".reference/src/commands/assistant/assistant.tsx",
    ".reference/src/assistant/AssistantSessionChooser.tsx",
    ".reference/src/utils/protectedNamespace.ts",
    ".reference/src/entrypoints/sdk/runtimeTypes.ts",
    ".reference/src/entrypoints/sdk/settingsTypes.generated.ts",
    ".reference/src/entrypoints/sdk/toolTypes.ts",
    ".reference/src/entrypoints/sdk/coreTypes.generated.ts",
    ".reference/src/utils/filePersistence/types.ts",
    ".reference/src/components/agents/SnapshotUpdateDialog.tsx",
    ".reference/src/utils/permissions/bashClassifier.ts",
    ".reference/src/skills/bundled/verify/SKILL.md",
    ".reference/stubs/@ant/computer-use-mcp/src/executor.ts",
    ".reference/stubs/@ant/computer-use-mcp/src/subGates.ts",
}


def basename_swift(path):
    """Convert a filename to a .swift name (strip ext, PascalCase if needed)."""
    base = os.path.basename(path)
    # strip extension
    stem = re.sub(r'\.(tsx?|d\.ts|md|txt|json|yaml|yml|sh|py)$', '', base)
    return stem


def classify(path):
    """Return (swift_target, status, notes) for a given .reference/ path."""
    rel = path[len(".reference/"):]  # strip .reference/ prefix

    # --- stubs/ ---
    if rel.startswith("stubs/downloads/"):
        stem = basename_swift(path)
        return (f"Sources/SwiftCodeVendored/{stem}", "asset", "vendored npm package source")
    if rel.startswith("stubs/@ant/"):
        stem = basename_swift(path)
        return (f"Sources/SwiftCodeStubs/{stem}", "stub", "proprietary extracted Anthropic code")
    if rel.startswith("stubs/@anthropic-ai/"):
        stem = basename_swift(path)
        return (f"Sources/SwiftCodeVendored/{stem}", "asset", "vendored Anthropic SDK package")
    if rel.startswith("stubs/color-diff-napi"):
        return ("Sources/SwiftCodeVendored/", "asset", "vendored native addon stub")

    # --- shims/ (other than seeded) ---
    if rel.startswith("shims/"):
        stem = basename_swift(path)
        return (f"Sources/SwiftCodeCore/{stem}.swift", "rewrite", "port shim to Swift")

    # --- docs/ ---
    if rel.startswith("docs/"):
        return ("docs/reference/", "reference-only", "reference documentation")

    # --- scripts/ ---
    if rel.startswith("scripts/"):
        return ("docs/reference/", "reference-only", "TypeScript build script, replaced by SwiftPM")

    # --- src/ ---
    if rel.startswith("src/"):
        return classify_src(path, rel[len("src/"):])

    # fallback
    return ("docs/reference/", "reference-only", "miscellaneous reference file")


def classify_src(full_path, rel):
    """Classify a src/ path."""

    # Stub files first
    if full_path in STUB_PATHS:
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeStubs/{stem}.swift", "stub", "documented stub — ant-only or feature-gated")

    # entrypoints/
    if rel.startswith("entrypoints/sdk/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeSDK/{stem}.swift", "rewrite", "port SDK entrypoint")
    if rel.startswith("entrypoints/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeCLI/{stem}.swift", "rewrite", "port CLI entrypoint")

    # tools/
    if rel.startswith("tools/"):
        parts = rel[len("tools/"):].split("/")
        tool_dir = parts[0] if parts else ""
        stem = basename_swift(full_path)
        if tool_dir and tool_dir not in ("", "tools.ts"):
            return (f"Sources/SwiftCodeTools/{tool_dir}/{stem}.swift", "rewrite", "port tool to Swift")
        return (f"Sources/SwiftCodeTools/{stem}.swift", "rewrite", "port tool to Swift")

    # commands/
    if rel.startswith("commands/"):
        parts = rel[len("commands/"):].split("/")
        cmd_dir = parts[0] if parts else ""
        stem = basename_swift(full_path)
        if cmd_dir:
            return (f"Sources/SwiftCodeCommands/{cmd_dir}/{stem}.swift", "rewrite", "port command to Swift")
        return (f"Sources/SwiftCodeCommands/{stem}.swift", "rewrite", "port command to Swift")

    # components/ + ink/
    if rel.startswith("components/") or rel.startswith("ink/"):
        parts = rel.split("/")
        subdir = parts[1] if len(parts) > 1 else ""
        stem = basename_swift(full_path)
        if subdir and "." not in subdir:
            return (f"Sources/SwiftCodeTerminalUI/{subdir}/{stem}.swift", "rewrite", "port terminal UI component")
        return (f"Sources/SwiftCodeTerminalUI/{stem}.swift", "rewrite", "port terminal UI component")

    # services/mcp/
    if rel.startswith("services/mcp/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeMCP/{stem}.swift", "rewrite", "port MCP service")
    # services/lsp/
    if rel.startswith("services/lsp/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeLSP/{stem}.swift", "rewrite", "port LSP service")
    # services/api/ or services/oauth/
    if rel.startswith("services/api/") or rel.startswith("services/oauth/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeAPI/{stem}.swift", "rewrite", "port API/OAuth service")
    # services/ (other)
    if rel.startswith("services/"):
        stem = basename_swift(full_path)
        parts = rel[len("services/"):].split("/")
        subdir = parts[0] if parts else ""
        if subdir and "." not in subdir:
            return (f"Sources/SwiftCodeServices/{subdir}/{stem}.swift", "rewrite", "port service to Swift")
        return (f"Sources/SwiftCodeServices/{stem}.swift", "rewrite", "port service to Swift")

    # hooks/
    if rel.startswith("hooks/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeHooks/{stem}.swift", "rewrite", "port hook to Swift")

    # utils/settings/ or utils/config
    if rel.startswith("utils/settings/") or rel == "utils/config.ts":
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeSettings/{stem}.swift", "rewrite", "port settings/config to Swift")
    # utils/permissions/
    if rel.startswith("utils/permissions/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodePermissions/{stem}.swift", "rewrite", "port permissions logic")
    # utils/hooks/
    if rel.startswith("utils/hooks/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeHooks/{stem}.swift", "rewrite", "port hook utility")
    # utils/plugins/
    if rel.startswith("utils/plugins/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodePlugins/{stem}.swift", "rewrite", "port plugin utility")
    # utils/shell/ or utils/bash/
    if rel.startswith("utils/shell/") or rel.startswith("utils/bash/") or rel in ("utils/Shell.ts",):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeNative/{stem}.swift", "rewrite", "port shell utility to Swift")
    # utils/secureStorage/
    if rel.startswith("utils/secureStorage/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeNative/{stem}.swift", "rewrite", "port secure storage to Swift Keychain")
    # utils/deepLink/
    if rel.startswith("utils/deepLink/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeCLI/{stem}.swift", "rewrite", "port deep link handling")
    # utils/telemetry/
    if rel.startswith("utils/telemetry/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeTelemetry/{stem}.swift", "rewrite", "port telemetry")
    # utils/swarm/
    if rel.startswith("utils/swarm/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeAgent/{stem}.swift", "rewrite", "port agent swarm utility")
    # utils/model/
    if rel.startswith("utils/model/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeAPI/{stem}.swift", "rewrite", "port model utility")
    # utils/computerUse/
    if rel.startswith("utils/computerUse/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeStubs/{stem}.swift", "stub", "computer use — needs native binaries")
    # utils/task/
    if rel.startswith("utils/task/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeAgent/{stem}.swift", "rewrite", "port task utility")
    # utils/claudeInChrome/ or utils/claudeAi*
    if rel.startswith("utils/claudeInChrome/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeStubs/{stem}.swift", "stub", "claude-in-chrome integration — ant-only")
    # utils/ultraplan/
    if rel.startswith("utils/ultraplan/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeStubs/{stem}.swift", "stub", "ultraplan feature — feature-gated")
    # utils/ misc
    if rel.startswith("utils/"):
        stem = basename_swift(full_path)
        # specific known files
        filename = os.path.basename(full_path)
        if filename in ("process.ts", "fsOperations.ts", "git.ts", "github.ts"):
            return (f"Sources/SwiftCodeNative/{stem}.swift", "rewrite", "port native utility to Swift")
        return (f"Sources/SwiftCodeCore/{stem}.swift", "rewrite", "port utility to Swift")

    # migrations/
    if rel.startswith("migrations/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeSettings/{stem}.swift", "rewrite", "port migration to Swift")

    # types/
    if rel.startswith("types/"):
        stem = basename_swift(full_path)
        filename = os.path.basename(full_path)
        if "permissions" in filename.lower():
            return (f"Sources/SwiftCodePermissions/{stem}.swift", "rewrite", "port permission types")
        return (f"Sources/SwiftCodeCore/{stem}.swift", "rewrite", "port core types")

    # context/
    if rel.startswith("context/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeAgent/{stem}.swift", "rewrite", "port context management")

    # bridge/
    if rel.startswith("bridge/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeRemote/{stem}.swift", "rewrite", "port bridge/remote communication")

    # remote/
    if rel.startswith("remote/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeRemote/{stem}.swift", "rewrite", "port remote handling")

    # server/
    if rel.startswith("server/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeRemote/{stem}.swift", "rewrite", "port server component")

    # coordinator/
    if rel.startswith("coordinator/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeRemote/{stem}.swift", "rewrite", "port coordinator — feature-gated")

    # tasks/
    if rel.startswith("tasks/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeAgent/{stem}.swift", "rewrite", "port task management")

    # cli/
    if rel.startswith("cli/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeRemote/{stem}.swift", "rewrite", "port CLI transport/bg")

    # vim/
    if rel.startswith("vim/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeVim/{stem}.swift", "rewrite", "port vim mode")

    # keybindings/
    if rel.startswith("keybindings/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeCLI/Keybindings/{stem}.swift", "rewrite", "port keybindings")

    # skills/
    if rel.startswith("skills/"):
        stem = basename_swift(full_path)
        filename = os.path.basename(full_path)
        if filename.endswith(".md"):
            return (f"Sources/SwiftCodePlugins/Skills/{stem}.md", "asset", "bundled skill asset")
        return (f"Sources/SwiftCodePlugins/{stem}.swift", "rewrite", "port skill system")

    # plugins/
    if rel.startswith("plugins/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodePlugins/{stem}.swift", "rewrite", "port plugin entry")

    # constants/
    if rel.startswith("constants/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeCore/{stem}.swift", "rewrite", "port constants")

    # query/
    if rel.startswith("query/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeAgent/{stem}.swift", "rewrite", "port query component")

    # native-ts/ (yoga layout)
    if rel.startswith("native-ts/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeTerminalUI/{stem}.swift", "rewrite", "port yoga layout to SwiftUI/custom layout")

    # state/
    if rel.startswith("state/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeCore/{stem}.swift", "rewrite", "port state management")

    # bootstrap/
    if rel.startswith("bootstrap/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeCLI/{stem}.swift", "rewrite", "port bootstrap state")

    # memdir/
    if rel.startswith("memdir/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeAgent/{stem}.swift", "rewrite", "port memory directory")

    # buddy/ (onboarding)
    if rel.startswith("buddy/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeCLI/{stem}.swift", "rewrite", "port onboarding/buddy flow")

    # assistant/
    if rel.startswith("assistant/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeStubs/{stem}.swift", "stub", "assistant install wizard — not in leak")

    # upstreamproxy/
    if rel.startswith("upstreamproxy/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeAPI/{stem}.swift", "rewrite", "port upstream proxy support")

    # moreright/
    if rel.startswith("moreright/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeStubs/{stem}.swift", "stub", "ant-only more-right panel")

    # schemas/
    if rel.startswith("schemas/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeCore/{stem}.swift", "rewrite", "port schema definitions")

    # screens/ (other than seeded REPL)
    if rel.startswith("screens/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeCLI/{stem}.swift", "rewrite", "port screen component")

    # outputStyles/
    if rel.startswith("outputStyles/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeTerminalUI/{stem}.swift", "rewrite", "port output styles")

    # voice/
    if rel.startswith("voice/"):
        stem = basename_swift(full_path)
        return (f"Sources/SwiftCodeStubs/{stem}.swift", "stub", "voice mode — feature-gated")

    # top-level src files (not already seeded)
    stem = basename_swift(full_path)
    filename = os.path.basename(full_path)

    if filename == "tasks.ts":
        return ("Sources/SwiftCodeAgent/Tasks.swift", "rewrite", "port tasks module")
    if filename == "Task.ts":
        return ("Sources/SwiftCodeAgent/Task.swift", "rewrite", "port Task type")
    if filename == "setup.ts":
        return ("Sources/SwiftCodeCLI/Setup.swift", "rewrite", "port setup logic")
    if filename == "replLauncher.tsx":
        return ("Sources/SwiftCodeCLI/REPLLauncher.swift", "rewrite", "port REPL launcher")
    if filename == "projectOnboardingState.ts":
        return ("Sources/SwiftCodeCore/ProjectOnboardingState.swift", "rewrite", "port onboarding state")
    if filename == "outputStyles":
        return ("Sources/SwiftCodeTerminalUI/OutputStyles.swift", "rewrite", "port output styles")
    if filename == "interactiveHelpers.tsx":
        return ("Sources/SwiftCodeCLI/InteractiveHelpers.swift", "rewrite", "port interactive helpers")
    if filename == "ink.ts":
        return ("Sources/SwiftCodeTerminalUI/InkBridge.swift", "rewrite", "port ink bridge")
    if filename == "history.ts":
        return ("Sources/SwiftCodeAgent/History.swift", "rewrite", "port history")
    if filename == "dialogLaunchers.tsx":
        return ("Sources/SwiftCodeCLI/DialogLaunchers.swift", "rewrite", "port dialog launchers")
    if filename == "costHook.ts":
        return ("Sources/SwiftCodeAPI/CostHook.swift", "rewrite", "port cost hook")
    if filename == "cost-tracker.ts":
        return ("Sources/SwiftCodeAPI/CostTracker.swift", "rewrite", "port cost tracker")
    if filename == "context.ts":
        return ("Sources/SwiftCodeAgent/Context.swift", "rewrite", "port context module")

    # fallback for src/
    return (f"Sources/SwiftCodeCore/{stem}.swift", "rewrite", "port to Swift — classify further when porting")


def main():
    with open("Tests/Golden/reference-files.txt") as f:
        paths = [line.strip() for line in f if line.strip()]

    rows = []
    for path in paths:
        if path in SEED_PATHS:
            continue
        swift_target, status, notes = classify(path)
        rows.append((path, swift_target, status, notes))

    for path, swift_target, status, notes in rows:
        print(f"{path}\t{swift_target}\t{status}\t{notes}")


if __name__ == "__main__":
    main()
