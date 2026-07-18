import Foundation
@testable import NeuAuthKit

// MARK: - Fixtures

enum Fixture {
    static let config = NeuAuthConfig(
        issuerBaseURL: URL(string: "https://neuauth.example.app")!,
        clientID: "test-client-id",
        scopes: "openid profile email"
    )

    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Craft an UNSIGNED JWT with the given payload (signature is fake —
    /// NeuAuthKit never verifies locally).
    static func jwt(_ payload: [String: Any]) -> String {
        func segment(_ object: [String: Any]) -> String {
            let data = try! JSONSerialization.data(withJSONObject: object)
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return "\(segment(["alg": "RS256", "typ": "JWT"])).\(segment(payload)).c2lnbmF0dXJl"
    }

    /// A token set whose access token is a real (unsigned) JWT expiring at
    /// `expiresAt`.
    static func tokens(
        accessExpiresAt: Date,
        refreshToken: String? = "refresh-1",
        isAnonymous: Bool = false
    ) -> NeuAuthTokens {
        var payload: [String: Any] = [
            "sub": "user-1",
            "exp": accessExpiresAt.timeIntervalSince1970,
        ]
        if isAnonymous { payload["is_anonymous"] = true }
        return NeuAuthTokens(
            accessToken: jwt(payload),
            refreshToken: refreshToken,
            idToken: nil,
            expiresAt: accessExpiresAt
        )
    }

    static func grantJSON(
        accessToken: String, refreshToken: String = "refresh-2", expiresIn: Int = 900
    ) -> Data {
        Data(
            """
            {"access_token":"\(accessToken)","token_type":"Bearer","expires_in":\(expiresIn),"refresh_token":"\(refreshToken)"}
            """.utf8
        )
    }
}

// MARK: - HTTP stub

/// Scripted transport for `AuthSession`: records every request and routes
/// responses through a caller-provided handler. Thread-safe.
final class HTTPStub: @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    private let respond: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    init(respond: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)) {
        self.respond = respond
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    func requestCount(pathContains fragment: String) -> Int {
        requests.filter { $0.url?.path.contains(fragment) == true }.count
    }

    var handler: AuthSession.DataHandler {
        { [self] request in
            lock.lock()
            _requests.append(request)
            lock.unlock()
            return try await respond(request)
        }
    }

    static func response(
        _ request: URLRequest, status: Int, body: Data = Data("{}".utf8)
    ) -> (Data, HTTPURLResponse) {
        (
            body,
            HTTPURLResponse(
                url: request.url ?? URL(string: "https://neuauth.example.app")!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }
}

/// Simple async gate: `wait()` suspends until `open()` is called.
actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            if isOpen {
                continuation.resume()
            } else {
                waiters.append(continuation)
            }
        }
    }

    func open() {
        isOpen = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }
}

// MARK: - Helpers

func bodyJSON(_ request: URLRequest) -> [String: Any] {
    guard let body = request.httpBody,
          let object = try? JSONSerialization.jsonObject(with: body),
          let dict = object as? [String: Any]
    else { return [:] }
    return dict
}

/// Yield repeatedly so freshly-spawned tasks can reach their first
/// suspension point (used to close actor-hop races in concurrency tests).
func megaYield(_ count: Int = 200) async {
    for _ in 0..<count { await Task.yield() }
}
