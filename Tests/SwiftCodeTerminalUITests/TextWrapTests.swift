import XCTest
@testable import SwiftCodeTerminalUI

final class TextWrapTests: XCTestCase {
    func testSingleLineFits() {
        XCTAssertEqual(TextWrap.wrap("hello", width: 10), ["hello"])
    }

    func testWrapsAtWord() {
        XCTAssertEqual(TextWrap.wrap("hello world", width: 5), ["hello", "world"])
    }

    func testLongWordSplits() {
        XCTAssertEqual(TextWrap.wrap("abcdefghij", width: 4), ["abcd", "efgh", "ij"])
    }

    func testRespectsExistingNewlines() {
        XCTAssertEqual(TextWrap.wrap("a\nb", width: 10), ["a", "b"])
    }

    func testCellWidthAscii() {
        XCTAssertEqual(TextWrap.cellWidth("hello"), 5)
    }

    func testCellWidthCjk() {
        XCTAssertEqual(TextWrap.cellWidth("中"), 2)
        XCTAssertEqual(TextWrap.cellWidth("中文"), 4)
    }

    func testEmptyInputProducesEmptyLine() {
        XCTAssertEqual(TextWrap.wrap("", width: 5), [""])
    }
}
