import XCTest
@testable import MimiMoneyCore

final class AccountBalanceEditPrefillTests: XCTestCase {
    /// Bug repro: 设定期初 must NOT prefill current balance (e.g. TNG 48.02).
    func testOpeningModePrefillsInitialBalanceNotCurrentBalance() {
        let amount = AccountBalanceEditPrefill.amount(
            mode: .setOpening,
            balance: 48.02,
            initialBalance: 101.62
        )
        XCTAssertEqual(amount, 101.62, accuracy: 0.0001)
        XCTAssertNotEqual(amount, 48.02, accuracy: 0.0001)

        let text = AccountBalanceEditPrefill.formattedInput(
            mode: .setOpening,
            balance: 48.02,
            initialBalance: 101.62
        )
        XCTAssertEqual(text, "101.62")
    }

    func testCalibrateModePrefillsCurrentBalance() {
        let amount = AccountBalanceEditPrefill.amount(
            mode: .calibrateCurrent,
            balance: 48.02,
            initialBalance: 101.62
        )
        XCTAssertEqual(amount, 48.02, accuracy: 0.0001)

        let text = AccountBalanceEditPrefill.formattedInput(
            mode: .calibrateCurrent,
            balance: 48.02,
            initialBalance: 101.62
        )
        XCTAssertEqual(text, "48.02")
    }

    func testOpeningModeShowsZeroWhenInitialNeverSet() {
        let amount = AccountBalanceEditPrefill.amount(
            mode: .setOpening,
            balance: 48.02,
            initialBalance: 0
        )
        XCTAssertEqual(amount, 0, accuracy: 0.0001)
        XCTAssertEqual(
            AccountBalanceEditPrefill.formattedInput(
                mode: .setOpening,
                balance: 48.02,
                initialBalance: 0
            ),
            "0.00"
        )
    }

    func testSwitchingModesUpdatesPrefillIndependently() {
        let balance = 48.02
        let initial = 9.03
        let opening = AccountBalanceEditPrefill.formattedInput(
            mode: .setOpening,
            balance: balance,
            initialBalance: initial
        )
        let calibrate = AccountBalanceEditPrefill.formattedInput(
            mode: .calibrateCurrent,
            balance: balance,
            initialBalance: initial
        )
        XCTAssertEqual(opening, "9.03")
        XCTAssertEqual(calibrate, "48.02")
        XCTAssertNotEqual(opening, calibrate)
    }

    func testModeFromSegmentTag() {
        XCTAssertEqual(AccountBalanceEditPrefill.Mode(rawValue: 0), .setOpening)
        XCTAssertEqual(AccountBalanceEditPrefill.Mode(rawValue: 1), .calibrateCurrent)
        XCTAssertNil(AccountBalanceEditPrefill.Mode(rawValue: 2))
    }

    func testNewAccountEmptyOpeningBalancePersistsZero() {
        let parsed = AccountBalanceEditPrefill.parseNewAccountOpeningBalance("")
        XCTAssertEqual(parsed, 0, accuracy: 0.0001)

        let whitespace = AccountBalanceEditPrefill.parseNewAccountOpeningBalance("   ")
        XCTAssertEqual(whitespace, 0, accuracy: 0.0001)

        let filled = AccountBalanceEditPrefill.parseNewAccountOpeningBalance("12.50")
        XCTAssertEqual(filled, 12.50, accuracy: 0.0001)
    }
}
