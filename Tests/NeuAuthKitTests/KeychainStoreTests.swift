import Foundation
@testable import NeuAuthKit
import Testing

@Suite("KeychainStore")
struct KeychainStoreTests {
    @Test("tokens round-trip and clear")
    func tokensRoundTrip() throws {
        let store = InMemoryKeychainStore()
        let tokens = NeuAuthTokens(
            accessToken: "a",
            refreshToken: "r",
            idToken: "i",
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(try store.loadTokens() == nil)
        try store.saveTokens(tokens)
        #expect(try store.loadTokens() == tokens)
        try store.clearTokens()
        #expect(try store.loadTokens() == nil)
    }

    @Test("device id is a separate item — clearing tokens keeps it")
    func deviceIDIndependence() throws {
        let store = InMemoryKeychainStore()
        try store.saveDeviceID("device-7")
        try store.saveTokens(
            NeuAuthTokens(accessToken: "a", refreshToken: nil, idToken: nil, expiresAt: .distantFuture)
        )

        try store.clearTokens()
        #expect(try store.loadDeviceID() == "device-7")

        try store.clearDeviceID()
        #expect(try store.loadDeviceID() == nil)
    }

    @Test("loadOrCreateDeviceID is stable across calls")
    func loadOrCreateStable() throws {
        let store = InMemoryKeychainStore()
        let first = try store.loadOrCreateDeviceID()
        let second = try store.loadOrCreateDeviceID()
        #expect(first == second)
        #expect(UUID(uuidString: first) != nil)

        // Pre-existing id is never replaced.
        let seeded = InMemoryKeychainStore(deviceID: "existing-id")
        #expect(try seeded.loadOrCreateDeviceID() == "existing-id")
    }

    @Test("NeuAuthTokens expiry applies a 60 s safety margin")
    func tokenExpiryMargin() {
        let tokens = NeuAuthTokens(
            accessToken: "a", refreshToken: nil, idToken: nil,
            expiresAt: Fixture.now.addingTimeInterval(90)
        )
        #expect(!tokens.isExpired(now: Fixture.now))
        #expect(tokens.isExpired(now: Fixture.now.addingTimeInterval(31)))  // inside margin
        #expect(tokens.isExpired(now: Fixture.now.addingTimeInterval(120)))
    }
}
