import SwiftUI

/// Drop-in "More Apps by byAlif" section for any SwiftUI List or Form.
///
/// Usage:
/// ```swift
/// List {
///     // ... existing sections ...
///     MoreAppsSection(excludingBundleID: "com.your.bundle.id")
/// }
/// ```
public struct MoreAppsSection: View {
    private let excludingBundleID: String

    @State private var apps: [AppInfo]

    public init(excludingBundleID: String) {
        self.excludingBundleID = excludingBundleID
        self._apps = State(initialValue: AppInfo.allByAlif.filter { $0.bundleID != excludingBundleID })
    }

    public var body: some View {
        Section {
            ForEach(apps) { app in
                appRow(app)
            }
        } header: {
            Text("More Apps by byAlif")
        }
        .task {
            let fresh = await AppPromoClient.fetchApps(excluding: excludingBundleID)
            if !fresh.isEmpty {
                apps = fresh
            }
        }
    }

    @ViewBuilder
    private func appRow(_ app: AppInfo) -> some View {
        if let url = URL(string: app.appStoreURL) {
            Link(destination: url) {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: app.iconURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.15))
                                .overlay {
                                    Image(systemName: "app.fill")
                                        .foregroundStyle(.secondary)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text(app.tagline)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

#if DEBUG
#Preview {
    List {
        MoreAppsSection(excludingBundleID: "com.subtracker.ios")
    }
}
#endif
