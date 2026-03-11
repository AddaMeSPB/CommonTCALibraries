import Foundation

// MARK: - Cache

private actor AppPromoCache {
    nonisolated(unsafe) static let shared = AppPromoCache()

    private var cachedApps: [AppInfo]?
    private var cacheDate: Date?
    private let ttl: TimeInterval = 86400  // 24 hours

    func get() -> [AppInfo]? {
        guard let date = cacheDate, let apps = cachedApps else { return nil }
        return Date().timeIntervalSince(date) < ttl ? apps : nil
    }

    func set(_ apps: [AppInfo]) {
        cachedApps = apps
        cacheDate = Date()
    }
}

// MARK: - Fetcher

public enum AppPromoClient {
    private static let appsURL = URL(string: "https://raw.githubusercontent.com/saroar/byalif-apps/main/apps.json")!

    /// Returns apps excluding the given bundle ID.
    /// - Uses 24-hour in-memory cache.
    /// - Falls back to bundled data on network failure.
    public static func fetchApps(excluding bundleID: String) async -> [AppInfo] {
        let cache = AppPromoCache.shared
        let exclude: ([AppInfo]) -> [AppInfo] = { $0.filter { $0.bundleID != bundleID } }

        if let cached = await cache.get() {
            return exclude(cached)
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: appsURL)
            let response = try JSONDecoder().decode(AppsResponse.self, from: data)
            await cache.set(response.apps)
            return exclude(response.apps)
        } catch {
            return exclude(AppInfo.allByAlif)
        }
    }
}
