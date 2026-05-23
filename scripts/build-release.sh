#!/usr/bin/env bash
set -euo pipefail
swift build -c release
mkdir -p dist
cp .build/release/swiftcode dist/swiftcode
dist/swiftcode --version
