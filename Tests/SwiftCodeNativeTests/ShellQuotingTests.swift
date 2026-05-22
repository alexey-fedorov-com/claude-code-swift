import Testing
@testable import SwiftCodeNative

/// These tests match the behavior of the `shell-quote` npm package used by
/// the TypeScript reference source. The expected values were verified against
/// `shell-quote` v1.x via Node.js.
@Suite("ShellQuoting")
struct ShellQuotingTests {

    // MARK: Bash — single-argument escaping

    @Test("testBashQuoteSimple: safe tokens pass through unchanged")
    func testBashQuoteSimple() {
        #expect(ShellQuoting.bashEscape("foo") == "foo")
        #expect(ShellQuoting.bashEscape("hello123") == "hello123")
        #expect(ShellQuoting.bashEscape("foo/bar") == "foo/bar")
        #expect(ShellQuoting.bashEscape("foo-bar") == "foo-bar")
        #expect(ShellQuoting.bashEscape("foo.bar") == "foo.bar")
    }

    @Test("testBashQuoteSpaces: tokens with spaces are single-quoted")
    func testBashQuoteSpaces() {
        // shell-quote wraps whitespace-only-special tokens in single quotes
        #expect(ShellQuoting.bashEscape("foo bar") == "'foo bar'")
        #expect(ShellQuoting.bashEscape("hello world") == "'hello world'")
    }

    @Test("testBashQuoteSingleQuote: tokens with single-quotes use double-quote wrapping")
    func testBashQuoteSingleQuote() {
        // shell-quote uses double-quotes when a single-quote is present
        #expect(ShellQuoting.bashEscape("foo'bar") == "\"foo'bar\"")
        #expect(ShellQuoting.bashEscape("it's") == "\"it's\"")
        // A bare single-quote → "'"
        #expect(ShellQuoting.bashEscape("'") == "\"'\"")
    }

    @Test("testBashQuoteSpecials: shell metacharacters are backslash-escaped")
    func testBashQuoteSpecials() {
        // shell-quote backslash-escapes individual special chars (no space involved)
        #expect(ShellQuoting.bashEscape("$x") == "\\$x")
        #expect(ShellQuoting.bashEscape("&") == "\\&")
        #expect(ShellQuoting.bashEscape(";") == "\\;")
        #expect(ShellQuoting.bashEscape("|") == "\\|")
        #expect(ShellQuoting.bashEscape(">") == "\\>")
        #expect(ShellQuoting.bashEscape("<") == "\\<")
        #expect(ShellQuoting.bashEscape("*") == "\\*")
        #expect(ShellQuoting.bashEscape("?") == "\\?")
        #expect(ShellQuoting.bashEscape("!") == "\\!")
    }

    @Test("testBashQuoteEmpty: empty string is quoted")
    func testBashQuoteEmpty() {
        #expect(ShellQuoting.bashEscape("") == "''")
    }

    // MARK: Bash — multi-argument joining

    @Test("testBashQuoteJoin: arguments are space-joined")
    func testBashQuoteJoin() {
        #expect(ShellQuoting.bashQuote(["foo"]) == "foo")
        #expect(ShellQuoting.bashQuote(["foo", "bar"]) == "foo bar")
        #expect(ShellQuoting.bashQuote(["foo bar", "baz"]) == "'foo bar' baz")
        #expect(ShellQuoting.bashQuote(["echo", "hello world"]) == "echo 'hello world'")
    }

    @Test("testBashQuoteEmptyArray: empty array produces empty string")
    func testBashQuoteEmptyArray() {
        #expect(ShellQuoting.bashQuote([]) == "")
    }

    // MARK: PowerShell — single-argument escaping

    @Test("testPowershellEscapeSimple: safe token unchanged")
    func testPowershellEscapeSimple() {
        #expect(ShellQuoting.powershellEscape("foo") == "foo")
        #expect(ShellQuoting.powershellEscape("hello123") == "hello123")
    }

    @Test("testPowershellEscapeSpaces: tokens with spaces are double-quoted")
    func testPowershellEscapeSpaces() {
        #expect(ShellQuoting.powershellEscape("foo bar") == "\"foo bar\"")
    }

    @Test("testPowershellEscapeDoubleQuote: embedded double-quote is backtick-escaped")
    func testPowershellEscapeDoubleQuote() {
        // foo"bar → "foo`"bar"
        #expect(ShellQuoting.powershellEscape("foo\"bar") == "\"foo`\"bar\"")
    }

    @Test("testPowershellEscapeBacktick: backtick is doubled")
    func testPowershellEscapeBacktick() {
        // foo`bar → "foo``bar"
        #expect(ShellQuoting.powershellEscape("foo`bar") == "\"foo``bar\"")
    }

    @Test("testPowershellEscapeDollar: dollar sign is backtick-escaped")
    func testPowershellEscapeDollar() {
        #expect(ShellQuoting.powershellEscape("$var") == "\"`$var\"")
    }

    // MARK: PowerShell — multi-argument joining

    @Test("testPowershellQuoteJoin: arguments are space-joined")
    func testPowershellQuoteJoin() {
        // C:\foo has only safe chars (alphanumeric + backslash + colon)
        #expect(ShellQuoting.powershellQuote(["Get-Item", "C:\\foo"]) == "Get-Item C:\\foo")
        #expect(ShellQuoting.powershellQuote(["Write-Host", "hello world"]) == "Write-Host \"hello world\"")
    }
}
