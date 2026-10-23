import Foundation

// MARK: - AppConfig

enum AppConfig {
    /// Toggle to enable admin-only screens. Set to `true` in internal/staff builds.
    static let isAdminBuild: Bool = false

    /// When enabled, care notes and family messages are translated server-side.
    static let serverSideTranslationEnabled: Bool = true

    /// Minimum iOS version required.
    static let minimumIOSVersion: String = "17.0"

    /// App Store bundle identifier.
    static let bundleIdentifier: String = "com.cura.app"

    /// Human-readable app name.
    static let appName: String = "Cura"

    /// Current build version string.
    static let buildVersion: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    /// Current short version string.
    static let shortVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    /// Base URL for the Cura API. Override with environment variable CURA_API_URL in debug.
    static let apiBaseURL: URL = {
        if let override = ProcessInfo.processInfo.environment["CURA_API_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://api.cura.app/v1")!
    }()

    /// Whether analytics and crash reporting are enabled. Off for debug builds.
    static var analyticsEnabled: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}
