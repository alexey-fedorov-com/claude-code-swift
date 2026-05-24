import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Opens a URL in the user's default browser.
///
/// On macOS we prefer `NSWorkspace.open(_:)` because it handles default-browser
/// resolution natively. As a portable fallback we shell out to `/usr/bin/open`,
/// which is what the reference CLI uses on macOS / Linux.
public enum BrowserLauncher {

    @discardableResult
    public static func open(_ url: URL) -> Bool {
        #if canImport(AppKit)
        if NSWorkspace.shared.open(url) {
            return true
        }
        #endif
        return shellOpen(url)
    }

    private static func shellOpen(_ url: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }
}
