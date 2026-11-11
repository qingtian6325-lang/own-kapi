import XCTest
@testable import MimiMoneyCore

final class ModelAndCatalogTests: XCTestCase {
    func testExpenseAndIncomeCatalogExactCounts() {
        let expenses = DefaultCatalog.standardExpenseCategories()
        XCTAssertEqual(expenses.count, 15)
        let totalExpenseSubs = expenses.reduce(0) { $0 + $1.subCategories.count }
        XCTAssertEqual(totalExpenseSubs, 51)
        XCTAssertTrue(expenses.contains(where: { $0.name == "家用" && $0.isCustom }))
        XCTAssertTrue(expenses.contains(where: { $0.name == "车贷" && $0.isCustom }))

        let incomes = DefaultCatalog.standardIncomeCategories()
        XCTAssertEqual(incomes.count, 9)
        XCTAssertTrue(incomes.contains(where: { $0.name == "别人转账" && $0.isCustom }))
    }

    func testDefaultAccountsMatchScreenshots() {
        let accounts = DefaultCatalog.defaultAccounts()
        XCTAssertEqual(accounts.map(\.name), ["现金", "CIMB", "TNGewallet", "PBBank"])
        let totalNetWorth = accounts.reduce(0.0) { $0 + $1.balance }
        XCTAssertEqual(totalNetWorth, 368.42, accuracy: 0.001)
    }

    func testFirstCharIconDisplayExtraction() {
        let cat = CategoryGroup(
            id: "custom_piano",
            name: "琴房学费",
            type: .expense,
            iconName: "music.note",
            useFirstCharIcon: true,
            isCustom: true,
            subCategories: [],
            sortOrder: 99
        )
        XCTAssertEqual(cat.displayBadgeToken, "琴")
    }
}
