import Foundation
@testable import NeuAuthKit
import Testing

@Suite("JWT claims (unverified local decode)")
struct JWTClaimsTests {
    @Test("decodes sub, exp, email and is_anonymous=true")
    func decodeAnonymous() {
        let exp = Fixture.now.addingTimeInterval(900)
        let token = Fixture.jwt([
            "sub": "user-42",
            "exp": exp.timeIntervalSince1970,
            "is_anonymous": true,
            "email": "a@b.c",
        ])
        let claims = JWTClaims(unverifiedJWT: token)
        #expect(claims?.subject == "user-42")
        #expect(claims?.expiresAt == Date(timeIntervalSince1970: exp.timeIntervalSince1970))
        #expect(claims?.isAnonymous == true)
        #expect(claims?.email == "a@b.c")
    }

    @Test("absent is_anonymous claim means registered user (false)")
    func absentIsAnonymous() {
        // NeuAuth omits the claim entirely for registered users.
        let token = Fixture.jwt(["sub": "user-1", "exp": 2_000_000_000])
        #expect(JWTClaims(unverifiedJWT: token)?.isAnonymous == false)
    }

    @Test("malformed tokens decode to nil")
    func malformed() {
        #expect(JWTClaims(unverifiedJWT: "") == nil)
        #expect(JWTClaims(unverifiedJWT: "not-a-jwt") == nil)
        #expect(JWTClaims(unverifiedJWT: "a.b") == nil)
        #expect(JWTClaims(unverifiedJWT: "a.!!!notbase64!!!.c") == nil)
        // Structurally valid but payload is not a JSON object
        let arrayPayload = "eyJhbGciOiJSUzI1NiJ9.WzEsMl0.sig"  // payload [1,2]
        #expect(JWTClaims(unverifiedJWT: arrayPayload) == nil)
    }

    @Test("base64url payloads with - and _ characters decode")
    func base64URLAlphabet() {
        // Craft a payload whose base64 contains '+' and '/' in standard
        // encoding, ensuring our '-'/'_' mapping is exercised.
        let payload: [String: Any] = ["sub": "??>>??~~", "exp": 2_000_000_000]
        let claims = JWTClaims(unverifiedJWT: Fixture.jwt(payload))
        #expect(claims?.subject == "??>>??~~")
    }

    @Test("secondsUntilExpiry applies the buffer and floors at zero")
    func secondsUntilExpiry() {
        let claims = JWTClaims(
            subject: nil,
            expiresAt: Fixture.now.addingTimeInterval(300),
            isAnonymous: false,
            email: nil
        )
        #expect(claims.secondsUntilExpiry(buffer: 120, now: Fixture.now) == 180)
        #expect(
            claims.secondsUntilExpiry(buffer: 120, now: Fixture.now.addingTimeInterval(250)) == 0
        )
        let noExp = JWTClaims(subject: nil, expiresAt: nil, isAnonymous: false, email: nil)
        #expect(noExp.secondsUntilExpiry(buffer: 120, now: Fixture.now) == 0)
    }
}

@Suite("PKCE")
struct PKCETests {
    @Test("RFC 7636 appendix B test vector")
    func rfcVector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        #expect(PKCE.challenge(for: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test("generated pairs are valid base64url and self-consistent")
    func generate() {
        let params = PKCE.generate()
        #expect(params.codeVerifier.count == 43)
        #expect(PKCE.challenge(for: params.codeVerifier) == params.codeChallenge)
        #expect(!params.codeChallenge.contains("="))
        #expect(!params.codeChallenge.contains("+"))
        #expect(!params.codeChallenge.contains("/"))
    }
}
