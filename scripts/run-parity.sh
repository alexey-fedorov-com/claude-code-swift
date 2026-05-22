#!/usr/bin/env bash
set -euo pipefail

swift build
PACKAGE_BINARY="$PWD/.build/debug/swiftcode" swift test
swift scripts/check-reference-coverage.swift
swift scripts/compare-cli-output.swift
