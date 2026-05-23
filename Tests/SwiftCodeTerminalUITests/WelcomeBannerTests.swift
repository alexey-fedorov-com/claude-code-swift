import XCTest
@testable import SwiftCodeTerminalUI

final class WelcomeBannerTests: XCTestCase {
    private func collectRow(_ screen: Screen, row: Int) -> String {
        var s = ""
        for c in 0..<screen.width {
            s.append(screen.cell(at: c, row: row).character)
        }
        return s
    }

    private func collectAll(_ screen: Screen) -> String {
        (0..<screen.height).map { collectRow(screen, row: $0) }.joined(separator: "\n")
    }

    func testWelcomeBannerHeaderContainsProductAndVersion() {
        let view = WelcomeBanner(version: "2.1.88")
        let screen = renderViewToScreen(view, width: 58, height: 20)
        let header = collectRow(screen, row: 0)
        XCTAssertTrue(header.contains("Welcome to Swift Code"),
                      "header should contain product name; got: \(header)")
        XCTAssertTrue(header.contains("v2.1.88"),
                      "header should contain version; got: \(header)")
    }

    func testWelcomeBannerContainsClawdBodyArt() {
        let view = WelcomeBanner(version: "2.1.88")
        let screen = renderViewToScreen(view, width: 58, height: 20)
        let all = collectAll(screen)
        XCTAssertTrue(all.contains("█████████"),
                      "should contain clawd body row; rendered:\n\(all)")
        XCTAssertTrue(all.contains("██▄█████▄██"),
                      "should contain clawd body cross-bar row; rendered:\n\(all)")
    }

    func testWelcomeBannerWidthIs58() {
        XCTAssertEqual(ClawdArt.width, 58)
    }
}
