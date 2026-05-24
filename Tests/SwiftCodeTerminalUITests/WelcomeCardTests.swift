import XCTest
@testable import SwiftCodeTerminalUI

final class WelcomeCardTests: XCTestCase {
    private func collectRow(_ screen: Screen, row: Int) -> String {
        var s = ""
        for c in 0..<screen.width {
            s.append(screen.cell(at: c, row: row).character)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private func collectAll(_ screen: Screen) -> String {
        (0..<screen.height).map { collectRow(screen, row: $0) }
            .joined(separator: "\n")
    }

    func testCardRendersRoundedBorder() {
        let card = WelcomeCard(version: "2.1.88", cwd: "~/proj", width: 60)
        // Make the render screen tight to the card so the bottom row IS the
        // bottom border.
        let screen = renderViewToScreen(card, width: 60, height: 30)
        let top = collectRow(screen, row: 0)
        XCTAssertTrue(top.hasPrefix("╭"), "top border should start with ╭, got: \(top)")
        XCTAssertTrue(top.hasSuffix("╮"), "top border should end with ╮, got: \(top)")
        // Find the bottom border row (first row containing ╰).
        let bottomRow = (0..<screen.height).first { collectRow(screen, row: $0).hasPrefix("╰") }
        XCTAssertNotNil(bottomRow, "card should render a bottom border somewhere")
        if let r = bottomRow {
            let bottom = collectRow(screen, row: r)
            XCTAssertTrue(bottom.hasSuffix("╯"),
                          "bottom border should end with ╯, got: \(bottom)")
        }
    }

    func testCardShowsTitleInTopBorder() {
        let card = WelcomeCard(version: "2.1.88", width: 60)
        let screen = renderViewToScreen(card, width: 60, height: 12)
        let top = collectRow(screen, row: 0)
        XCTAssertTrue(top.contains("Swift Code"),
                      "top border should contain product name, got: \(top)")
        XCTAssertTrue(top.contains("v2.1.88"),
                      "top border should contain version, got: \(top)")
    }

    func testCardShowsWelcomeMessage() {
        let card = WelcomeCard(version: "1.0.0", width: 60)
        let screen = renderViewToScreen(card, width: 60, height: 12)
        let body = collectAll(screen)
        XCTAssertTrue(body.contains("Welcome back!"),
                      "card body should contain greeting; rendered:\n\(body)")
    }

    func testCardShowsPersonalizedGreeting() {
        let card = WelcomeCard(version: "1.0.0", username: "Alexey", width: 60)
        let screen = renderViewToScreen(card, width: 60, height: 12)
        let body = collectAll(screen)
        XCTAssertTrue(body.contains("Welcome back Alexey!"),
                      "card body should personalize greeting; rendered:\n\(body)")
    }

    func testCardRendersPiggyArt() {
        let card = WelcomeCard(version: "1.0.0", width: 60)
        let screen = renderViewToScreen(card, width: 60, height: 12)
        let body = collectAll(screen)
        // The small Clawd has a 5-block body row and a feet row with ▘▘ ▝▝.
        XCTAssertTrue(body.contains("█████"),
                      "card should contain pig body row; rendered:\n\(body)")
        XCTAssertTrue(body.contains("▘▘ ▝▝"),
                      "card should contain pig feet row; rendered:\n\(body)")
    }

    func testCardShowsCwdWhenProvided() {
        let card = WelcomeCard(version: "1.0.0",
                               cwd: "/Users/alexey/proj", width: 60)
        let screen = renderViewToScreen(card, width: 60, height: 13)
        let body = collectAll(screen)
        XCTAssertTrue(body.contains("/Users/alexey/proj"),
                      "card should render cwd; rendered:\n\(body)")
    }

    func testTruncateToWidth() {
        XCTAssertEqual(WelcomeCard.truncateToWidth("short", maxCells: 10), "short")
        XCTAssertEqual(WelcomeCard.truncateToWidth("a very long string here", maxCells: 10),
                       "a very lo…")
        XCTAssertEqual(WelcomeCard.truncateToWidth("hi", maxCells: 0), "")
    }
}
