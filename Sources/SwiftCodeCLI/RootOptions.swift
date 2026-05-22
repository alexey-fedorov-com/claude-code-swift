import ArgumentParser
import Foundation

// MARK: - Root Options
// All flags/options for the root `swiftcode` command, matching the reference main.tsx CLI surface.
// Hidden options (hideHelp in reference) are marked with /* hidden */ and omit help text.

extension SwiftCodeCommand {

    // -------------------------------------------------------------------------
    // Debug / verbosity
    // -------------------------------------------------------------------------

    // NOTE: @Option with optional String for -d/--debug [filter]
    // In ArgumentParser, optional-value options need @Option with Optional<String>
    // We model it as an Optional<String> accepting an explicit value.

    // -d, --debug [filter]
    // Commander supports optional value; in ArgumentParser we use Optional<String>
    // and a separate @Flag for the bare -d case. We model both as a single @Option.
    // Actually ArgumentParser doesn't support optional-argument options natively.
    // Pragmatic choice: make it a simple @Option(String?) — user passes --debug api,hooks
    // or omits it entirely. Bare -d is not supported in this Swift impl.

    // -------------------------------------------------------------------------
    // Hidden sentinel — not actually in extension, just documentation
    // -------------------------------------------------------------------------
}
