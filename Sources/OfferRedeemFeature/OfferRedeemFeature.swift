import ComposableArchitecture
import Foundation
import OfferRedeemClient
#if canImport(UIKit)
import StoreKit
import UIKit
#endif

@Reducer
public struct OfferRedeemFeature: Sendable {
    private enum CancelID { case network }

    @ObservableState
    public struct State: Equatable {
        public var step: Step = .email
        public var email: String = ""
        public var verifyCode: String = ""
        public var claimId: String = ""
        public var claimToken: String = ""
        public var marketingConsent: Bool = false
        public var isLoading: Bool = false
        public var error: String?
        public var message: String?
        public var redemptionURL: String?
        public var promoCode: String?

        // Configuration
        public var environment: OfferRedeemEnvironment
        public var strings: OfferRedeemStrings

        public init(
            environment: OfferRedeemEnvironment,
            strings: OfferRedeemStrings = .defaults
        ) {
            self.environment = environment
            self.strings = strings
        }
    }

    public enum Step: String, Equatable, Sendable {
        case email
        case verify
        case appClaim
        case success
    }

    public enum Action: BindableAction, Equatable, Sendable {
        case binding(BindingAction<State>)
        case onAppear
        case submitEmail
        case submitVerification
        case submitAppClaim
        case resendVerification
        case goBackToEmail
        case openRedemptionURL
        case openPrivacyPolicy
        case openTermsOfUse
        case presentOfferCodeSheet
        case _preclaimResult(Result<OfferPreclaimResponse, OfferRedeemError>)
        case _verifyResult(Result<OfferVerifyResponse, OfferRedeemError>)
        case _appClaimResult(Result<OfferClaimResponse, OfferRedeemError>)
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case dismissed
            case redeemed
            case flowStarted
            case couponRedeemed
        }
    }

    @Dependency(\.offerRedeemClient) var offerClient
    @Dependency(\.openURL) var openURL

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .merge(
                    .send(.delegate(.flowStarted)),
                    .run { _ in
                        try? await offerClient.registerDevice()
                    }
                )

            // MARK: - Submit Email

            case .submitEmail:
                let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !email.isEmpty, email.contains("@") else {
                    state.error = state.strings.invalidEmail
                    return .none
                }
                state.error = nil
                state.isLoading = true
                let slug = state.environment.campaignSlug
                let consent = state.marketingConsent
                return .run { [offerClient] send in
                    do {
                        let response = try await offerClient.preclaim(slug, email, consent)
                        await send(._preclaimResult(.success(response)))
                    } catch is CancellationError {
                        return
                    } catch let error as OfferRedeemError {
                        await send(._preclaimResult(.failure(error)))
                    } catch {
                        await send(._preclaimResult(.failure(.networkError(error.localizedDescription))))
                    }
                }
                .cancellable(id: CancelID.network, cancelInFlight: true)

            case let ._preclaimResult(.success(response)):
                state.isLoading = false
                if response.status == "already_claimed" || response.status == "waitlisted" {
                    state.message = response.message ?? state.strings.alreadyClaimed
                    state.step = .success
                    return .none
                }
                // Only overwrite if response includes new values (resend may omit them)
                if let newClaimId = response.claim_id, !newClaimId.isEmpty {
                    state.claimId = newClaimId
                }
                if let newToken = response.claim_token, !newToken.isEmpty {
                    state.claimToken = newToken
                }
                let requiresVerification = response.requires_verification ?? true
                if requiresVerification {
                    state.step = .verify
                } else if !state.claimToken.isEmpty {
                    state.step = .appClaim
                    return .send(.submitAppClaim)
                } else {
                    state.message = state.strings.claimRegistered
                    state.step = .success
                }
                return .none

            case let ._preclaimResult(.failure(error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            // MARK: - Verify Code

            case .submitVerification:
                let code = state.verifyCode.trimmingCharacters(in: .whitespacesAndNewlines)
                guard code.count >= 6 else {
                    state.error = state.strings.enterFullCode
                    return .none
                }
                state.error = nil
                state.isLoading = true
                let claimId = state.claimId
                let claimToken = state.claimToken
                return .run { [offerClient] send in
                    do {
                        let response = try await offerClient.verify(claimId, code, claimToken)
                        await send(._verifyResult(.success(response)))
                    } catch is CancellationError {
                        return
                    } catch let error as OfferRedeemError {
                        await send(._verifyResult(.failure(error)))
                    } catch {
                        await send(._verifyResult(.failure(.networkError(error.localizedDescription))))
                    }
                }
                .cancellable(id: CancelID.network, cancelInFlight: true)

            case let ._verifyResult(.success(response)):
                state.isLoading = false
                if let newToken = response.claim_token {
                    state.claimToken = newToken
                }

                switch response.next_step {
                case "app_claim":
                    state.step = .appClaim
                    return .send(.submitAppClaim)

                case "code_delivery":
                    state.promoCode = response.code
                    state.redemptionURL = response.redemption_url
                    state.message = response.message ?? state.strings.couponSentToEmail
                    state.step = .success
                    return .send(.delegate(.couponRedeemed))

                default:
                    state.message = response.message ?? state.strings.couponSentToEmail
                    state.step = .success
                    return .none
                }

            case let ._verifyResult(.failure(error)):
                state.isLoading = false
                state.error = error.localizedDescription
                state.verifyCode = ""
                return .none

            // MARK: - Resend Verification

            case .resendVerification:
                state.error = nil
                state.isLoading = true
                state.verifyCode = ""
                let slug = state.environment.campaignSlug
                let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
                let consent = state.marketingConsent
                return .run { [offerClient] send in
                    do {
                        let response = try await offerClient.preclaim(slug, email, consent)
                        await send(._preclaimResult(.success(response)))
                    } catch is CancellationError {
                        return
                    } catch let error as OfferRedeemError {
                        await send(._preclaimResult(.failure(error)))
                    } catch {
                        await send(._preclaimResult(.failure(.networkError(error.localizedDescription))))
                    }
                }
                .cancellable(id: CancelID.network, cancelInFlight: true)

            // MARK: - Go Back

            case .goBackToEmail:
                state.step = .email
                state.verifyCode = ""
                state.claimId = ""
                state.claimToken = ""
                state.error = nil
                state.isLoading = false
                return .cancel(id: CancelID.network)

            // MARK: - App Claim

            case .submitAppClaim:
                state.isLoading = true
                state.error = nil
                let slug = state.environment.campaignSlug
                let token = state.claimToken
                return .run { [offerClient] send in
                    do {
                        let response = try await offerClient.appClaim(slug, token)
                        await send(._appClaimResult(.success(response)))
                    } catch is CancellationError {
                        return
                    } catch let error as OfferRedeemError {
                        await send(._appClaimResult(.failure(error)))
                    } catch {
                        await send(._appClaimResult(.failure(.networkError(error.localizedDescription))))
                    }
                }
                .cancellable(id: CancelID.network, cancelInFlight: true)

            case let ._appClaimResult(.success(response)):
                state.isLoading = false
                state.promoCode = response.code
                state.redemptionURL = response.redemption_url
                state.message = response.message ?? state.strings.success
                state.step = .success
                return .send(.delegate(.couponRedeemed))

            case let ._appClaimResult(.failure(error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            // MARK: - URL Actions

            case .openPrivacyPolicy:
                return .run { [url = state.environment.privacyURL] _ in
                    await openURL(url)
                }

            case .openTermsOfUse:
                return .run { [url = state.environment.termsURL] _ in
                    await openURL(url)
                }

            case .openRedemptionURL:
                guard let urlString = state.redemptionURL,
                      let url = URL(string: urlString) else { return .none }
                return .run { _ in
                    await openURL(url)
                }

            case .presentOfferCodeSheet:
                #if os(iOS)
                return .run { _ in
                    let scene = await MainActor.run {
                        UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .first
                    }
                    guard let scene else { return }
                    try? await AppStore.presentOfferCodeRedeemSheet(in: scene)
                }
                #else
                return .none
                #endif

            case .delegate:
                return .none
            }
        }
    }
}
