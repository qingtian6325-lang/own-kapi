import Foundation

/// Locates the SPM resource bundle for `MimiMoneyCore` without calling generated
/// `Bundle.module` (which `fatalError`s when the `.bundle` was not copied into the IPA).
enum MimiResourceBundle {
    /// SPM names the bundle `{Package.name}_{Target.name}.bundle`.
    static let preferredBundleName = "MimiMoney_MimiMoneyCore"
    /// Historical / mistaken CI search name — still probe for safety.
    static let legacyBundleName = "MimiMoneyCore_MimiMoneyCore"

    /// Resolved catalog / asset bundle. Never fatals; falls back to `Bundle.main`
    /// so a missing IPA resource bundle cannot crash launch (keys may show as source).
    static let bundle: Bundle = resolve()

    static var didFallBackToMain: Bool { bundle === Bundle.main }

    private static func resolve() -> Bundle {
        let names = [preferredBundleName, legacyBundleName]
        for name in names {
            for candidate in candidateURLs(bundleName: name) {
                if let found = Bundle(url: candidate) {
                    return found
                }
            }
        }
        // Last resort: Bundle.main keeps the process alive (Chinese source keys).
        return Bundle.main
    }

    private static func candidateURLs(bundleName: String) -> [URL] {
        let fileName = "\(bundleName).bundle"
        var urls: [URL] = []
        let main = Bundle.main
        if let resourceURL = main.resourceURL {
            urls.append(resourceURL.appendingPathComponent(fileName))
        }
        urls.append(main.bundleURL.appendingPathComponent(fileName))
        // Nested frameworks / plugins style paths used by some SPM layouts.
        if let frameworksPath = main.privateFrameworksPath {
            urls.append(URL(fileURLWithPath: frameworksPath).appendingPathComponent(fileName))
        }
        let thisBundle = Bundle(for: BundleFinder.self)
        if let resourceURL = thisBundle.resourceURL {
            urls.append(resourceURL.appendingPathComponent(fileName))
        }
        urls.append(thisBundle.bundleURL.appendingPathComponent(fileName))
        // macOS `swift test` host: resources sit beside the test bundle.
        if let executables = thisBundle.executableURL?.deletingLastPathComponent() {
            urls.append(executables.appendingPathComponent(fileName))
        }
        return urls
    }
}

private final class BundleFinder: NSObject {}

public extension Bundle {
    /// Safe substitute for SPM `Bundle.module` — never fatals if the IPA omitted the resource bundle.
    static var mimiModule: Bundle { MimiResourceBundle.bundle }
}
