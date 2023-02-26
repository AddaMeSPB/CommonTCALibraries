import Foundation
import Dependencies
import XCTestDynamicOverlay
import FoundationExtension
import os

public enum ServiceKeys: NSString {
  case token, deviceToken, voipToken, user, mobileNumbers, serverContacts, deviceinfo,
    cllocation2d
}

public struct KeychainClient {

    enum KeychainError: Error {
        // Attempted read for an item that does not exist.
        case itemNotFound

        // Attempted save to override an existing item.
        // Use update instead of save to update existing items
        case duplicateItem

        // A read of an item in any format other than Data
        case invalidItemFormat

        // Any operation result status than errSecSuccess
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

    public typealias SavehHandler = @Sendable (
        _ data: Data,
        _ service: ServiceKeys,
        _ account: String
    )  async throws -> Void

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

    var save: SavehHandler
    var read: ReadHandler
    var update: UpdateHandler
    var delete: DeleteHandler

    public init(
        save: @escaping SavehHandler,
        read: @escaping ReadHandler,
        update: @escaping UpdateHandler,
        delete: @escaping DeleteHandler
    ) {
        self.save = save
        self.read = read
        self.update = update
        self.delete = delete
    }

    @Sendable public func saveCodable<T: Codable>(
        _ item: T,
        _ service: ServiceKeys,
        _ account: String
    ) async throws -> Void {
        do {
            // Encode as JSON data and save in keychain
            let data = try JSONEncoder().encode(item)
            try await save(data, service, account)

        } catch {
            // 92 The operation couldn’t be completed.
            // (KeychainClient.KeychainClient.KeychainError error 3.)

            logger.error("\(#file) \(#line) saveCodable: \(error.localizedDescription)")
            throw error.localizedDescription
        }
    }

    @Sendable public func readCodable<T: Codable>(
        _ service: ServiceKeys,
        _ account: String,
        _ type: T.Type
    ) throws -> T {
        do {
            // Read item data from keychain
            let data = try read(service, account)

            // Decode JSON data to object
            let item = try JSONDecoder().decode(type, from: data)
            return item
        } catch {
            logger.error("\(#file) \(#line) readCodable: \(error.localizedDescription)")
            throw KeychainError.itemNotFound
        }
    }

    @Sendable public func updateCodable<T: Codable>(
        _ item: T,
        _ service: ServiceKeys,
        _ account: String
    ) async throws -> Void {
        do {
            // Encode as JSON data and save in keychain
            let data = try JSONEncoder().encode(item)
            try await update(data, service, account)

        } catch {

            logger.error("\(#file) \(#line) updateCodable: \(error.localizedDescription)")
            throw error.localizedDescription
        }
    }


    @Sendable public func deleteByKey(
        _ service: ServiceKeys,
        _ account: String
    ) async throws -> Void {
        do {
            try await delete(service, account)
        } catch {
            logger.error("\(#file) \(#line) deleteByKey: \(error.localizedDescription)")
            throw error.localizedDescription
        }
    }

    @Sendable public func logout() async throws -> Void {
        let secItemClasses =  [
          kSecClassGenericPassword,
          kSecClassInternetPassword,
          kSecClassCertificate,
          kSecClassKey,
          kSecClassIdentity,
        ]
        for itemClass in secItemClasses {
          let spec: NSDictionary = [kSecClass: itemClass]
          SecItemDelete(spec)
        }
      }

}

extension KeychainClient: DependencyKey {

    static public var liveValue: KeychainClient = .init(
        save: { data, key, account in
            let query: [String: AnyObject] = [
                // kSecAttrService,  kSecAttrAccount, and kSecClass
                // uniquely identify the item to save in Keychain
                kSecAttrService as String: key.rawValue as AnyObject,
                kSecAttrAccount as String: account as AnyObject,
                kSecClass as String: kSecClassGenericPassword,

                // kSecValueData is the item value to save
                kSecValueData as String: data as AnyObject
            ]

            // SecItemAdd attempts to add the item identified by
            // the query to keychain
            let status = SecItemAdd(query as CFDictionary, nil)

            // errSecDuplicateItem is a special case where the
            // item identified by the query already exists. Throw
            // duplicateItem so the client can determine whether
            // or not to handle this as an error
            if status == errSecDuplicateItem {
                throw KeychainError.init(status: status)
            }

            // Any status other than errSecSuccess indicates the
            // save operation failed.
            guard status == errSecSuccess else {
                throw KeychainError.unexpectedStatus(status)
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
