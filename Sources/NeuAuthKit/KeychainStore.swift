import Foundation
#if canImport(Security)
import Security
#endif

// MARK: - Protocol

/// Secure storage for the token set and the anonymous device identifier.
///
/// The device id lives in a **separate keychain item** from the tokens:
/// keychain items survive app reinstall on iOS, so a user who deletes and
/// reinstalls the app reconnects to the same anonymous account (same closet)
/// via `POST /auth/anonymous` with the persisted `device_id` — even though
/// their tokens may be long gone.
public protocol KeychainStore: Sendable {
    func loadTokens() throws -> NeuAuthTokens?
    func saveTokens(_ tokens: NeuAuthTokens) throws
    func clearTokens() throws

    func loadDeviceID() throws -> String?
    func saveDeviceID(_ deviceID: String) throws
    func clearDeviceID() throws
}

extension KeychainStore {
    /// Return the persisted device id, generating and persisting a fresh
    /// UUID on first use.
    public func loadOrCreateDeviceID() throws -> String {
        if let existing = try loadDeviceID() { return existing }
        let fresh = UUID().uuidString
        try saveDeviceID(fresh)
        return fresh
    }
}

// MARK: - In-Memory (tests, previews)

public final class InMemoryKeychainStore: KeychainStore, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: NeuAuthTokens?
    private var deviceID: String?

    public init(tokens: NeuAuthTokens? = nil, deviceID: String? = nil) {
        self.tokens = tokens
        self.deviceID = deviceID
    }

    public func loadTokens() throws -> NeuAuthTokens? {
        lock.lock(); defer { lock.unlock() }
        return tokens
    }

    public func saveTokens(_ tokens: NeuAuthTokens) throws {
        lock.lock(); defer { lock.unlock() }
        self.tokens = tokens
    }

    public func clearTokens() throws {
        lock.lock(); defer { lock.unlock() }
        tokens = nil
    }

    public func loadDeviceID() throws -> String? {
        lock.lock(); defer { lock.unlock() }
        return deviceID
    }

    public func saveDeviceID(_ deviceID: String) throws {
        lock.lock(); defer { lock.unlock() }
        self.deviceID = deviceID
    }

    public func clearDeviceID() throws {
        lock.lock(); defer { lock.unlock() }
        deviceID = nil
    }
}

// MARK: - Live Keychain-backed implementation

#if canImport(Security)
/// Keychain-backed store. `service` is injected by the consuming app
/// (e.g. `"com.byalif.closetkind.neuauth"`) — no hardcoded defaults.
public struct LiveKeychainStore: KeychainStore {
    public let service: String
    public let tokensAccount: String
    public let deviceIDAccount: String

    public init(
        service: String,
        tokensAccount: String = "neuauth_tokens",
        deviceIDAccount: String = "neuauth_device_id"
    ) {
        self.service = service
        self.tokensAccount = tokensAccount
        self.deviceIDAccount = deviceIDAccount
    }

    // MARK: Tokens

    public func loadTokens() throws -> NeuAuthTokens? {
        guard let data = try loadData(account: tokensAccount) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            return try decoder.decode(NeuAuthTokens.self, from: data)
        } catch {
            // Corrupt/legacy payload — treat as signed out rather than
            // wedging every launch on a decode error.
            try? deleteItem(account: tokensAccount)
            return nil
        }
    }

    public func saveTokens(_ tokens: NeuAuthTokens) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(tokens)
        // Tokens are device-bound: ThisDeviceOnly keeps them out of backups
        // and device migrations (server sessions shouldn't hop devices).
        try saveData(
            data, account: tokensAccount,
            accessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )
    }

    public func clearTokens() throws {
        try deleteItem(account: tokensAccount)
    }

    // MARK: Device ID

    public func loadDeviceID() throws -> String? {
        guard let data = try loadData(account: deviceIDAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func saveDeviceID(_ deviceID: String) throws {
        // Unlike tokens, the device id intentionally survives backup restore
        // and device migration: it lets the user reconnect the same anonymous
        // account (same closet) on their new/restored device.
        try saveData(
            Data(deviceID.utf8), account: deviceIDAccount,
            accessible: kSecAttrAccessibleAfterFirstUnlock
        )
    }

    public func clearDeviceID() throws {
        try deleteItem(account: deviceIDAccount)
    }

    // MARK: Primitives

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func loadData(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw NeuAuthError.keychain(status: status)
        }
        return data
    }

    private func saveData(_ data: Data, account: String, accessible: CFString) throws {
        // Update-then-add: try an in-place update first (keeps the item's
        // identity/ACL), fall back to add when the item doesn't exist yet.
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(
            baseQuery(account: account) as CFDictionary,
            update as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw NeuAuthError.keychain(status: updateStatus)
        }

        var add = baseQuery(account: account)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = accessible
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw NeuAuthError.keychain(status: addStatus)
        }
    }

    private func deleteItem(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NeuAuthError.keychain(status: status)
        }
    }
}
#endif
