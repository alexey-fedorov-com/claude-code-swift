import XCTest
@testable import SwiftCodeTerminalUI

final class DialogTests: XCTestCase {
    private func screenText(_ screen: Screen) -> String {
        (0..<screen.height).map { row -> String in
            (0..<screen.width).map { String(screen.cell(at: $0, row: row).character) }.joined()
        }.joined(separator: "\n")
    }

    func testConfirmDialogShowsTitleAndOptions() {
        let view = ConfirmDialog(title: "Delete file?",
                                 detail: "/path/to/file.txt",
                                 yesLabel: "Yes",
                                 noLabel: "No",
                                 selected: .yes)
        let screen = renderViewToScreen(view, width: 60, height: 8)
        let text = screenText(screen)
        XCTAssertTrue(text.contains("Delete file?"), "missing title; got:\n\(text)")
        XCTAssertTrue(text.contains("/path/to/file.txt"), "missing detail")
        XCTAssertTrue(text.contains("> Yes"), "missing selected marker on Yes")
        XCTAssertTrue(text.contains("  No"), "missing unselected No")
    }

    func testConfirmDialogSelectsNo() {
        let view = ConfirmDialog(title: "Confirm?",
                                 yesLabel: "Yes",
                                 noLabel: "No",
                                 selected: .no)
        let screen = renderViewToScreen(view, width: 40, height: 6)
        let text = screenText(screen)
        XCTAssertTrue(text.contains("  Yes"))
        XCTAssertTrue(text.contains("> No"))
    }

    func testConfirmDialogHasRoundedBorder() {
        let view = ConfirmDialog(title: "Test", yesLabel: "Y", noLabel: "N", selected: .yes)
        let screen = renderViewToScreen(view, width: 30, height: 8)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, "╭")
    }

    func testPermissionRequestRendersToolNameAndArgs() {
        let view = PermissionRequestDialog(
            toolName: "Bash",
            description: "rm -rf foo/",
            options: [.allow, .allowAlways, .deny],
            selectedIndex: 0
        )
        let screen = renderViewToScreen(view, width: 60, height: 10)
        let text = screenText(screen)
        XCTAssertTrue(text.contains("Bash"), "missing toolName")
        XCTAssertTrue(text.contains("rm -rf foo/"), "missing description")
        XCTAssertTrue(text.contains("Allow"), "missing 'Allow' option label")
        XCTAssertTrue(text.contains("Allow always"), "missing 'Allow always'")
        XCTAssertTrue(text.contains("Deny"), "missing 'Deny'")
    }

    func testPermissionRequestSelectionMarker() {
        let view = PermissionRequestDialog(
            toolName: "Bash",
            description: "test",
            options: [.allow, .allowAlways, .deny],
            selectedIndex: 1
        )
        let screen = renderViewToScreen(view, width: 60, height: 10)
        let text = screenText(screen)
        XCTAssertTrue(text.contains("> Allow always"),
                      "selected option should have '> ' marker; rendered:\n\(text)")
    }
}
