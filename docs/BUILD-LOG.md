# Build Log

Documents the build commands for the Swift rewrite and how they map to the original Bun-based TypeScript build.

## Command Mapping

| Purpose | TypeScript (original) | Swift (this repo) |
|---|---|---|
| Install deps | `bun install` | _(none — SPM handles deps)_ |
| Debug build | `bun run build` | `swift build` |
| Release build | `bun run build` (single bundle) | `swift build -c release` |
| Run | `bun dist/cli.js` | `swift run swiftcode` |
| Run (installed) | `claude` | `swiftcode` |
| Test | _(none)_ | `swift test` |
| Dist binary | `dist/cli.js` (~23 MB) | `dist/swiftcode` (native binary) |

## Release Build

```bash
scripts/build-release.sh
```

1. `swift build -c release` — compiles all modules with optimizations
2. Copies `.build/release/swiftcode` → `dist/swiftcode`
3. Smoke-tests: `dist/swiftcode --version` should print `2.1.88 (Swift Code)`

## Local Install

```bash
scripts/install-local.sh
```

1. Runs the release build
2. Copies binary to `~/.local/bin/swiftcode`
3. Smoke-tests the installed binary

## Notes

- No watch mode or dev server — just rebuild and re-run
- Swift compiler caches incremental builds in `.build/`
- `.build/` is gitignored; clean with `rm -rf .build`
- `Package.resolved` is gitignored — commit it if you want reproducible dep versions
