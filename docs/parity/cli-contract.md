# CLI Parity Contract

The Swift executable is named `swiftcode`.

The root command description, version output, visible help text, hidden flag behavior, subcommand tree, aliases, exit codes, stdout, and stderr must match `.reference/dist/cli.js` after applying the intentional rebrand mapping: `Claude Code` -> `Swift Code` and command-token `claude` -> `swiftcode`.

Golden outputs live in `Tests/Golden/cli`.

Commands covered by mandatory golden tests:

- `swiftcode --version`
- `swiftcode -v`
- `swiftcode --help`
- `swiftcode mcp --help`
- `swiftcode auth --help`
- `swiftcode plugin --help`
- `swiftcode completion --help`
- `swiftcode -p ""`
- `swiftcode --dump-system-prompt`
