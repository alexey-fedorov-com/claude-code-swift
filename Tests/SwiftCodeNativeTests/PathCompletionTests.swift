import XCTest
@testable import SwiftCodeNative

final class PathCompletionTests: XCTestCase {
    var tmp: URL!

    override func setUp() {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        for name in ["alpha.txt", "beta.txt", "subdir", ".hidden"] {
            let url = tmp.appendingPathComponent(name)
            if name == "subdir" {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } else {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
        }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmp)
    }

    func testTopLevelCompletionsExcludeHidden() throws {
        let entries = try PathCompletion.complete(prefix: "", in: tmp.path)
        let names = entries.map(\.name).sorted()
        XCTAssertEqual(names, ["alpha.txt", "beta.txt", "subdir"])
    }

    func testHiddenIncludedWhenPrefixStartsWithDot() throws {
        let entries = try PathCompletion.complete(prefix: ".", in: tmp.path)
        XCTAssertTrue(entries.contains { $0.name == ".hidden" })
    }

    func testPrefixFilters() throws {
        let entries = try PathCompletion.complete(prefix: "a", in: tmp.path)
        XCTAssertEqual(entries.map(\.name), ["alpha.txt"])
    }

    func testDirectoryFlag() throws {
        let entries = try PathCompletion.complete(prefix: "", in: tmp.path)
        XCTAssertEqual(entries.first { $0.name == "subdir" }?.kind, .directory)
    }

    func testResultsSortedAlphabetically() throws {
        let entries = try PathCompletion.complete(prefix: "", in: tmp.path)
        let names = entries.map(\.name)
        XCTAssertEqual(names, names.sorted { $0.lowercased() < $1.lowercased() })
    }
}
