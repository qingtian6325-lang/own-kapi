import XCTest
@testable import MimiMoneyCore

final class AppVersionInfoTests: XCTestCase {
    func testSettingsFooterLineFormat() {
        XCTAssertEqual(
            AppVersionInfo.formatLine(shortVersion: "1.3.13", build: "42"),
            "版本 1.3.13 (build 42)"
        )
    }

    func testSettingsFooterLineUsesBundleKeysShape() {
        let line = AppVersionInfo.settingsFooterLine
        XCTAssertTrue(line.hasPrefix("版本 "), line)
        XCTAssertTrue(line.contains("(build "), line)
        XCTAssertTrue(line.hasSuffix(")"), line)
    }
}
