#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/build-release.sh"
mkdir -p "$HOME/.local/bin"
cp "$ROOT/dist/swiftcode" "$HOME/.local/bin/swiftcode"
"$HOME/.local/bin/swiftcode" --version
