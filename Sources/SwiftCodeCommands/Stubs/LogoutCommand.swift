import SwiftCodeCore
import SwiftCodeAPI

public struct LogoutCommand: SlashCommand {
    public let name = "logout"
    public let description = "Remove saved credentials from the Keychain"
    public init() {}

    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        let store = CredentialStore()
        do {
            try store.clear()
            return .logoutCompleted(message: "Logged out. Run /login to sign in again.")
        } catch {
            return .logoutCompleted(message: "Logout failed: \(error)")
        }
    }
}
