import Foundation
import Dependencies
import XCTestDynamicOverlay
import FoundationExtension
import os

public enum ServiceKeys: NSString {
    case token, deviceToken, voipToken, user, mobileNumbers, serverContacts, deviceinfo, cllocation2d
}

public struct KeychainClient {
    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case invalidItemFormat
        case unexpectedStatus(OSStatus)
        case errorStatus(String?)

        init(status: OSStatus) {
            switch status {
            case errSecItemNotFound:
                self = .itemNotFound
            case errSecDuplicateItem:
                self = .duplicateItem
            default:
                let message = SecCopyErrorMessageString(status, nil) as String?
                self = .errorStatus(message)
            }
        }
    }

    public typealias SaveHandler = @Sendable (
        _ data: Data,
        _ service: ServiceKeys,
        _ account: String
    ) async throws -> Void
    
    public typealias ReadHandler = @Sendable (
        _ service: ServiceKeys,
        _ account: String
    ) throws -> Data
    
    public typealias UpdateHandler = @Sendable (
        _ data: Data,
        _ service: ServiceKeys,
        _ account: String
    ) async throws -> Void

    public typealias DeleteHandler = @Sendable (
        _ service: ServiceKeys,
        _ account: String
    ) async throws -> Void

    var save: SaveHandler
    var read: ReadHandler
    var update: UpdateHandler
    var delete: DeleteHandler

    /// Initialises a new KeychainClient with specified handlers for keychain operations.
    public init(
        save: @escaping SaveHandler,
        read: @escaping ReadHandler,
        update: @escaping UpdateHandler,
        delete: @escaping DeleteHandler
    ) {
        self.save = save
        self.read = read
        self.update = update
        self.delete = delete
    }

    /// Saves a Codable item to the keychain. If the item already exists, it updates the existing item.
    /// - Parameters:
    ///   - item: The Codable item to save.
    ///   - service: The keychain service under which to save the item.
    ///   - account: The account name associated with the item.
    public func saveOrUpdateCodable<T: Codable>(
        _ item: T,
        _ service: ServiceKeys,
        _ account: String
    ) async throws -> Void {
        let data = try JSONEncoder().encode(item)
        do {
            try await save(data, service, account)
        } catch KeychainError.duplicateItem {
            try await update(data, service, account)
        } catch {
            logger.error("\(#file) \(#line) saveOrUpdateCodable: \(error.localizedDescription)")
            throw error
        }
    }

    /// Reads and decodes a Codable item from the keychain.
    /// - Parameters:
    ///   - service: The keychain service from which to read the item.
    ///   - account: The account name associated with the item.
    ///   - type: The type of the Codable item to read.
    /// - Returns: The decoded item.
    public func readCodable<T: Codable>(
        _ service: ServiceKeys,
        _ account: String,
        _ type: T.Type
    ) throws -> T {
        let data = try read(service, account)
        return try JSONDecoder().decode(type, from: data)
    }

    /// Deletes an item from the keychain by its service and account.
    /// - Parameters:
    ///   - service: The keychain service associated with the item to delete.
    ///   - account: The account name associated with the item.
    public func deleteByKey(
        _ service: ServiceKeys,
        _ account: String
    ) async throws -> Void {
        try await delete(service, account)
    }

    /// Clears all items from the keychain for the current application.
    public func logout() async throws -> Void {
        let secItemClasses = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]
        
        for itemClass in secItemClasses {
            let spec: NSDictionary = [kSecClass: itemClass]
            let status = SecItemDelete(spec)
            if status != errSecSuccess && status != errSecItemNotFound {
                let errorMessage = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
                logger.error("Failed to clear keychain items: \(errorMessage)")
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }
}

// Ensure to define logger, DependencyKey, and other extensions as previously described.


extension KeychainClient: DependencyKey {

    static public var liveValue: KeychainClient = .init(
        save: { data, service, account in
            let query: [String: AnyObject] = [
                kSecAttrService as String: service.rawValue as AnyObject,
                kSecAttrAccount as String: account as AnyObject,
                kSecClass as String: kSecClassGenericPassword,
                kSecValueData as String: data as AnyObject
            ]

            let status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecDuplicateItem {
                // If a duplicate item exists, update instead of throwing an error.
                let updateQuery: [String: AnyObject] = [
                    kSecAttrService as String: service.rawValue as AnyObject,
                    kSecAttrAccount as String: account as AnyObject,
                    kSecClass as String: kSecClassGenericPassword
                ]
                let attributesToUpdate: [String: AnyObject] = [
                    kSecValueData as String: data as AnyObject
                ]
                let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
                guard updateStatus == errSecSuccess else {
                    throw KeychainError.unexpectedStatus(updateStatus)
                }
            } else {
                guard status == errSecSuccess else {
                    throw KeychainError.unexpectedStatus(status)
                }
            }
        },

        read: { key, account in
            let query: [String: AnyObject] = [
                // kSecAttrService,  kSecAttrAccount, and kSecClass
                // uniquely identify the item to read in Keychain
                kSecAttrService as String: key.rawValue as AnyObject,
                kSecAttrAccount as String: account as AnyObject,
                kSecClass as String: kSecClassGenericPassword,

                // kSecMatchLimitOne indicates keychain should read
                // only the most recent item matching this query
                kSecMatchLimit as String: kSecMatchLimitOne,

                // kSecReturnData is set to kCFBooleanTrue in order
                // to retrieve the data for the item
                kSecReturnData as String: kCFBooleanTrue
            ]

            // SecItemCopyMatching will attempt to copy the item
            // identified by query to the reference itemCopy
            var itemCopy: AnyObject?
            let status = SecItemCopyMatching(
                query as CFDictionary,
                &itemCopy
            )

            // errSecItemNotFound is a special status indicating the
            // read item does not exist. Throw itemNotFound so the
            // client can determine whether or not to handle
            // this case
            guard status != errSecItemNotFound else {
                throw KeychainError.init(status: status)
            }

            // Any status other than errSecSuccess indicates the
            // read operation failed.
            guard status == errSecSuccess else {
                throw KeychainError.unexpectedStatus(status)
            }

            // This implementation of KeychainInterface requires all
            // items to be saved and read as Data. Otherwise,
            // invalidItemFormat is thrown
            guard let value = itemCopy as? Data else {
                throw KeychainError.invalidItemFormat
            }

            return value
        },

        update: {  data, key, account in
            let query: [String: AnyObject] = [
                // kSecAttrService,  kSecAttrAccount, and kSecClass
                // uniquely identify the item to update in Keychain
                kSecAttrService as String: key.rawValue as AnyObject,
                kSecAttrAccount as String: account as AnyObject,
                kSecClass as String: kSecClassGenericPassword
            ]

            // attributes is passed to SecItemUpdate with
            // kSecValueData as the updated item value
            let attributes: [String: AnyObject] = [
                kSecValueData as String: data as AnyObject
            ]

            // SecItemUpdate attempts to update the item identified
            // by query, overriding the previous value
            let status = SecItemUpdate(
                query as CFDictionary,
                attributes as CFDictionary
            )

            // errSecItemNotFound is a special status indicating the
            // item to update does not exist. Throw itemNotFound so
            // the client can determine whether or not to handle
            // this as an error
            guard status != errSecItemNotFound else {
                throw KeychainError(status: status)
            }

            // Any status other than errSecSuccess indicates the
            // update operation failed.
            guard status == errSecSuccess else {
                //throw KeychainError(status: errSecSuccess)
                throw KeychainError.unexpectedStatus(status)
            }
        },

        delete: { key, account in

            let query: [String: AnyObject] = [
                // kSecAttrService,  kSecAttrAccount, and kSecClass
                // uniquely identify the item to read in Keychain
                kSecAttrService as String: key.rawValue as AnyObject,
                kSecAttrAccount as String: account as AnyObject,
                kSecClass as String: kSecClassGenericPassword,

                // kSecMatchLimitOne indicates keychain should read
                // only the most recent item matching this query
                kSecMatchLimit as String: kSecMatchLimitOne,

                // kSecReturnData is set to kCFBooleanTrue in order
                // to retrieve the data for the item
                kSecReturnData as String: kCFBooleanTrue
            ]

            let status = SecItemDelete(query as CFDictionary)


            // errSecItemNotFound is a special status indicating the
            // read item does not exist. Throw itemNotFound so the
            // client can determine whether or not to handle
            // this case
            guard status != errSecItemNotFound else {
                throw KeychainError.init(status: status)
            }


            if status != errSecItemNotFound && status != errSecSuccess {
                throw KeychainError.unexpectedStatus(status)
            }
        }
    )
}

extension KeychainClient {
    public static let noop = Self(
        save: { _, _, _ in },
        read: { _,_ in Data() },
        update: { _, _, _ in },
        delete: { _, _ in }
    )
}

extension KeychainClient: TestDependencyKey {
    public static let previewValue = Self.noop

    static public var testValue: KeychainClient = .init(
        save: XCTUnimplemented("\(Self.self).save") ,
        read: XCTUnimplemented("\(Self.self).read", placeholder: Data()),
        update: XCTUnimplemented("\(Self.self).update"),
        delete: XCTUnimplemented("\(Self.self).delete")
    )
}

extension DependencyValues {
    public var keychainClient: KeychainClient {
        get { self[KeychainClient.self] }
        set { self[KeychainClient.self] = newValue }
    }
}

public let logger = Logger(subsystem: "com.addame.AddaMeIOS", category: "keychainClient")
