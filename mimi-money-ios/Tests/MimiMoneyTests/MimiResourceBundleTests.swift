import XCTest
@testable import MimiMoneyCore

final class MimiResourceBundleTests: XCTestCase {
    func testPreferredBundleNameMatchesSPMPackageTarget() {
        // Package.swift name "MimiMoney" + target "MimiMoneyCore"
        XCTAssertEqual(MimiResourceBundle.preferredBundleName, "MimiMoney_MimiMoneyCore")
    }

    func testMimiModuleNeverFatals() {
        // Accessing Bundle.mimiModule must not trap even if IPA omitted the SPM bundle.
        let bundle = Bundle.mimiModule
        XCTAssertNotNil(bundle.bundleURL)
        _ = MimiL10n.string("关闭", locale: Locale(identifier: "zh-Hans"))
    }

    func testLegacyNameDocumentedForCIProbe() {
        XCTAssertEqual(MimiResourceBundle.legacyBundleName, "MimiMoneyCore_MimiMoneyCore")
    }
}
