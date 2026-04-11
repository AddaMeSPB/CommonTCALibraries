import ComposableArchitecture
import Foundation
import OfferRedeemClient
@testable import OfferRedeemFeature
import Testing

@Suite("OfferRedeemFeature Tests")
@MainActor
struct OfferRedeemFeatureTests {

    private static let testEnvironment = OfferRedeemEnvironment(
        campaignSlug: "test-launch-2026",
        appName: "Test App Pro",
        privacyURL: URL(string: "https://example.com/privacy")!,
        termsURL: URL(string: "https://example.com/terms")!
    )

    @Test("onAppear sends flowStarted delegate")
    func onAppearSendsDelegate() async throws {
        let store = TestStore(
            initialState: OfferRedeemFeature.State(environment: Self.testEnvironment)
        ) {
            OfferRedeemFeature()
        } withDependencies: {
            $0.offerRedeemClient.registerDevice = {}
        }

        await store.send(.onAppear)
        await store.receive(.delegate(.flowStarted))
        // Drain the background registerDevice effect
        await store.finish()
    }

    @Test("submitEmail with invalid email shows error")
    func submitEmailInvalid() async throws {
        var state = OfferRedeemFeature.State(environment: Self.testEnvironment)
        state.email = "not-an-email"

        let store = TestStore(initialState: state) {
            OfferRedeemFeature()
        }

        await store.send(.submitEmail) {
            $0.error = OfferRedeemStrings.defaults.invalidEmail
        }
    }

    @Test("submitEmail with empty email shows error")
    func submitEmailEmpty() async throws {
        let store = TestStore(
            initialState: OfferRedeemFeature.State(environment: Self.testEnvironment)
        ) {
            OfferRedeemFeature()
        }

        await store.send(.submitEmail) {
            $0.error = OfferRedeemStrings.defaults.invalidEmail
        }
    }

    @Test("successful preclaim moves to verify step")
    func preclaimSuccess() async throws {
        var state = OfferRedeemFeature.State(environment: Self.testEnvironment)
        state.email = "test@example.com"

        let store = TestStore(initialState: state) {
            OfferRedeemFeature()
        } withDependencies: {
            $0.offerRedeemClient.preclaim = { _, _, _ in
                OfferPreclaimResponse(
                    status: "preclaimed",
                    claim_id: "claim-123",
                    claim_token: "token-abc",
                    requires_verification: true
                )
            }
        }

        await store.send(.submitEmail) {
            $0.error = nil
            $0.isLoading = true
        }

        await store.receive(._preclaimResult(.success(
            OfferPreclaimResponse(
                status: "preclaimed",
                claim_id: "claim-123",
                claim_token: "token-abc",
                requires_verification: true
            )
        ))) {
            $0.isLoading = false
            $0.claimId = "claim-123"
            $0.claimToken = "token-abc"
            $0.step = .verify
        }
    }

    @Test("already claimed goes to success")
    func alreadyClaimed() async throws {
        var state = OfferRedeemFeature.State(environment: Self.testEnvironment)
        state.email = "test@example.com"

        let store = TestStore(initialState: state) {
            OfferRedeemFeature()
        } withDependencies: {
            $0.offerRedeemClient.preclaim = { _, _, _ in
                OfferPreclaimResponse(status: "already_claimed", message: "Already claimed")
            }
        }

        await store.send(.submitEmail) {
            $0.error = nil
            $0.isLoading = true
        }

        await store.receive(._preclaimResult(.success(
            OfferPreclaimResponse(status: "already_claimed", message: "Already claimed")
        ))) {
            $0.isLoading = false
            $0.message = "Already claimed"
            $0.step = .success
        }
    }

    @Test("goBackToEmail resets verify state")
    func goBackToEmail() async throws {
        var state = OfferRedeemFeature.State(environment: Self.testEnvironment)
        state.step = .verify
        state.verifyCode = "123456"
        state.claimId = "claim-123"
        state.claimToken = "token-abc"
        state.error = "Some error"

        let store = TestStore(initialState: state) {
            OfferRedeemFeature()
        }

        await store.send(.goBackToEmail) {
            $0.step = .email
            $0.verifyCode = ""
            $0.claimId = ""
            $0.claimToken = ""
            $0.error = nil
        }
    }
}
