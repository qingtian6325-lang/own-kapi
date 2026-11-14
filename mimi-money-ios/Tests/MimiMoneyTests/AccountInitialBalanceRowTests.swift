import XCTest
@testable import MimiMoneyCore

final class AccountInitialBalanceRowTests: XCTestCase {
    func testDisplayUsesLiveInitialBalanceNeverPlaceholderZero() {
        let row = AccountInitialBalanceRowBuilder.make(
            initialBalance: 9.03,
            startDate: nil
        )
        XCTAssertEqual(row.title, "初始余额")
        XCTAssertEqual(row.amount, 9.03, accuracy: 0.0001)
        XCTAssertEqual(row.formattedAmount, MimiTheme.formatRM(9.03))
        XCTAssertFalse(row.formattedAmount.contains("RM0.00"))
        XCTAssertNil(row.startDateText)
    }

    func testDisplayShowsZeroOnlyWhenOpeningIsZero() {
        let row = AccountInitialBalanceRowBuilder.make(
            initialBalance: 0,
            startDate: nil
        )
        XCTAssertEqual(row.amount, 0, accuracy: 0.0001)
        XCTAssertEqual(row.formattedAmount, MimiTheme.formatRM(0))
    }

    func testDisplayIncludesStartDateWhenAvailable() {
        let cal = Calendar(identifier: .gregorian)
        let date = cal.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))!
        let row = AccountInitialBalanceRowBuilder.make(
            initialBalance: 48.02,
            startDate: date
        )
        XCTAssertEqual(row.startDateText, "2026.10.01")
        XCTAssertEqual(row.amount, 48.02, accuracy: 0.0001)
    }

    func testLiveAccountInitialBalanceUpdatesRowAmount() {
        let store = MimiStore(inMemory: true)
        store.resetToCleanEmpty()
        guard let tng = store.accounts.first(where: { $0.id == "acc_tng" }) else {
            return XCTFail("missing TNGewallet")
        }
        let before = AccountInitialBalanceRowBuilder.make(
            from: tng,
            startDate: AccountInitialBalanceRowBuilder.resolveStartDate(for: tng, auditLogs: store.auditLogs)
        )
        XCTAssertEqual(before.amount, tng.initialBalance, accuracy: 0.0001)

        store.setAccountInitialBalance(accountId: "acc_tng", initialBalance: 9.03)
        let live = store.accounts.first(where: { $0.id == "acc_tng" })!
        let after = AccountInitialBalanceRowBuilder.make(
            from: live,
            startDate: AccountInitialBalanceRowBuilder.resolveStartDate(for: live, auditLogs: store.auditLogs)
        )
        XCTAssertEqual(after.amount, 9.03, accuracy: 0.0001)
        XCTAssertEqual(after.formattedAmount, MimiTheme.formatRM(9.03))
        XCTAssertNotEqual(after.amount, before.amount, accuracy: 0.0001)
    }

    func testResolveStartDatePrefersAccountCreatedAt() {
        let cal = Calendar(identifier: .gregorian)
        let created = cal.date(from: DateComponents(year: 2026, month: 9, day: 15))!
        let account = AccountItem(
            id: "acc_x",
            name: "Test",
            subtitle: "",
            iconName: "💳",
            balance: 10,
            initialBalance: 10,
            createdAt: created
        )
        let resolved = AccountInitialBalanceRowBuilder.resolveStartDate(for: account, auditLogs: [])
        XCTAssertEqual(resolved, created)
    }
}
