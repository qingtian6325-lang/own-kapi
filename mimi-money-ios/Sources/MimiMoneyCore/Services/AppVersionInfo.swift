import Foundation

/// Reads marketing / build version from the app bundle for Settings footer copy.
public enum AppVersionInfo: Sendable {
    public static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "—"
    }

    public static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ?? "—"
    }

    /// Settings footer, e.g. `版本 1.3.18 (build 42)`.
    public static var settingsFooterLine: String {
        formatLine(shortVersion: shortVersion, build: build)
    }

    public static func formatLine(shortVersion: String, build: String) -> String {
        "版本 \(shortVersion) (build \(build))"
    }
}
