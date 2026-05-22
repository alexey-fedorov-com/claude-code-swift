import XCTest

final class VersionCommandTests: XCTestCase {
    func testVersionTextMatchesReferenceVersion() throws {
        let package = ProcessInfo.processInfo.environment["PACKAGE_BINARY"]
            ?? "\(FileManager.default.currentDirectoryPath)/.build/debug/swiftcode"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: package)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(output, "2.1.88 (Swift Code)\n")
    }
}
