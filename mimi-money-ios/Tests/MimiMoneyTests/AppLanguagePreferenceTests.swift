import XCTest
@testable import MimiMoneyCore

final class AppLanguagePreferenceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "mimi.language.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        if let suiteName {
            defaults?.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testDefaultPreferenceIsSystem() {
        let store = AppLanguageStore(defaults: defaults)
        XCTAssertEqual(store.preference, .system)
    }

    @MainActor
    func testPersistsPreference() {
        let store = AppLanguageStore(defaults: defaults)
        store.preference = .english
        XCTAssertEqual(defaults.string(forKey: AppLanguageStore.storageKey), "english")

        let reloaded = AppLanguageStore(defaults: defaults)
        XCTAssertEqual(reloaded.preference, .english)
        XCTAssertTrue(
            reloaded.effectiveLocale.identifier.hasPrefix("en"),
            "expected English locale, got \(reloaded.effectiveLocale.identifier)"
        )
    }

    @MainActor
    func testChineseLocaleOverride() {
        let store = AppLanguageStore(defaults: defaults)
        store.preference = .chinese
        XCTAssertEqual(store.effectiveLanguageCode, "zh-Hans")
        XCTAssertTrue(store.effectiveLocale.identifier.hasPrefix("zh"))
    }

    func testCatalogHasCoreUIStrings() {
        // Smoke: core keys resolve without crashing (bundle resources present).
        let close = MimiL10n.string("关闭", locale: Locale(identifier: "en"))
        let lang = MimiL10n.string("语言", locale: Locale(identifier: "en"))
        let product = MimiL10n.string("咪咪记账", locale: Locale(identifier: "en"))
        XCTAssertFalse(close.isEmpty)
        XCTAssertFalse(lang.isEmpty)
        XCTAssertFalse(product.isEmpty)
        // Prefer translated English when catalog is packaged in the test bundle.
        // On hosts without processed resources, String(localized:) may echo the key —
        // still assert non-empty above; assert English when available.
        if close != "关闭" {
            XCTAssertEqual(close, "Close")
        }
        if product != "咪咪记账" {
            XCTAssertEqual(product, "Mimi Money")
        }
    }
}
