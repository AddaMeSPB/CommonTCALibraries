import Foundation
import Security

/// Manages a per-device anonymous install token persisted in the Keychain.
/// The token survives app reinstalls (iOS Keychain behavior).
public enum InstallTokenManager {

    /// Returns the existing install token or generates a new UUID.
    /// - Parameter service: Keychain service identifier (from OfferRedeemConfig.keychainService)
    public static func installToken(service: String) -> String {
        if let stored = read(service: service, account: "install_token") {
            return stored
        }
        let token = UUID().uuidString.lowercased()
        let saved = write(service: service, account: "install_token", value: token)
        if saved {
            return token
        }
        // Retry read — another thread may have written concurrently
        if let stored = read(service: service, account: "install_token") {
            return stored
        }
        // Last resort — return unsaved token (will differ across calls if Keychain is broken)
        assertionFailure("Failed to persist install token to Keychain (service: \(service))")
        return token
    }

    // MARK: - Keychain Helpers

    private static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private static func write(service: String, account: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
}

// MARK: - Utilities

/// Mask email for logging: "user@example.com" -> "u***@example.com"
func maskedEmail(_ email: String) -> String {
    guard let atIndex = email.firstIndex(of: "@") else { return "***" }
    let prefix = email[email.startIndex..<atIndex]
    let domain = email[atIndex...]
    if prefix.count <= 1 { return "\(prefix)***\(domain)" }
    return "\(prefix.first!)***\(domain)"
}
