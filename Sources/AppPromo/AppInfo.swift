import Foundation

// MARK: - Model

public struct AppInfo: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let tagline: String
    public let iconURL: String
    public let appStoreURL: String
    public let platform: String
    public let bundleID: String
}

public struct AppsResponse: Codable, Sendable {
    public let version: Int
    public let apps: [AppInfo]
}

// MARK: - Bundled fallback (updated from apps.json at runtime)

extension AppInfo {
    public static let allByAlif: [AppInfo] = [
        AppInfo(
            id: "6759149326",
            name: "SubTracker",
            tagline: "Track all your subscriptions",
            iconURL: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/64/36/de/6436de53-ec52-045d-2a5d-cf79a80ff16b/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg",
            appStoreURL: "https://apps.apple.com/app/id6759149326",
            platform: "iOS+macOS",
            bundleID: "com.subtracker.ios"
        ),
        AppInfo(
            id: "6759658166",
            name: "FixLog",
            tagline: "Property maintenance tracker",
            iconURL: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/dc/49/60/dc49603d-6a50-c92e-74dd-e78037c0013e/AppIcon-0-0-1x_U007ephone-0-1-85-220.png/512x512bb.jpg",
            appStoreURL: "https://apps.apple.com/app/id6759658166",
            platform: "iOS",
            bundleID: "app.byalif.fixlog"
        ),
        AppInfo(
            id: "6759606866",
            name: "VoicePrice",
            tagline: "Voice-to-invoice in seconds",
            iconURL: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/97/59/d0/9759d008-1b0a-4df9-332a-378562e42c02/AppIcon-0-0-1x_U007emarketing-0-11-0-85-220.png/512x512bb.jpg",
            appStoreURL: "https://apps.apple.com/app/id6759606866",
            platform: "iOS",
            bundleID: "app.byalif.voiceprice"
        ),
        AppInfo(
            id: "6452084315",
            name: "eCardify",
            tagline: "Digital business cards",
            iconURL: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/c2/85/b0/c285b05f-1a56-6fab-1337-e8759dcd94e7/AppIconCircle-0-0-1x_U007epad-0-85-220.png/512x512bb.jpg",
            appStoreURL: "https://apps.apple.com/app/id6452084315",
            platform: "iOS",
            bundleID: "cardify.addame.com.eCardify"
        ),
        AppInfo(
            id: "6457363081",
            name: "iIntrvwBell",
            tagline: "Interview preparation & timer",
            iconURL: "https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/c5/0f/30/c50f30da-baaa-4cf4-f6bf-8267918c4af4/AppIcon-0-0-1x_U007epad-0-85-220.png/512x512bb.jpg",
            appStoreURL: "https://apps.apple.com/app/id6457363081",
            platform: "iOS",
            bundleID: "iInterviewBell.addame.com"
        ),
    ]
}
