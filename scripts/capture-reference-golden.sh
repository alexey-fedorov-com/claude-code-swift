#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="$ROOT/.reference/dist/cli.js"
OUT="$ROOT/Tests/Golden/cli"
mkdir -p "$OUT"

capture() {
  local name="$1"
  shift
  set +e
  # macOS-compatible 10-second timeout via perl (GNU `timeout` not available on macOS)
  perl -e 'alarm(10); exec @ARGV or exit 126' -- bun "$REF" "$@" >"$OUT/$name.stdout" 2>"$OUT/$name.stderr"
  local code=$?
  set -e
  printf "%s\n" "$code" >"$OUT/$name.exit"
}

capture version --version
capture short_version -v
capture help --help
capture mcp_help mcp --help
capture auth_help auth --help
capture plugin_help plugin --help
capture completion_help completion --help
capture print_empty -p ""
capture dump_system_prompt --dump-system-prompt
