import XCTest
@testable import MimiMoneyCore

@MainActor
final class BillCategorySelectionTests: XCTestCase {
    private var store: MimiStore!

    override func setUp() {
        super.setUp()
        store = MimiStore(inMemory: true)
    }

    func testParsesPrimaryAndSecondaryPath() {
        let selection = BillCategorySelection.from(
            type: .expense,
            categoryPath: "餐饮-零食甜品",
            expenseCategories: store.expenseCategories,
            incomeCategories: store.incomeCategories
        )
        XCTAssertEqual(selection.type, .expense)
        XCTAssertNotNil(selection.primaryId)
        XCTAssertNotNil(selection.secondaryId)
        let resolved = selection.resolvedPath(in: store.expenseCategories)
        XCTAssertEqual(resolved?.path, "餐饮-零食甜品")
    }

    func testParsesPrimaryOnlyPath() {
        guard let group = store.expenseCategories.first(where: { $0.subcategories.isEmpty })
                ?? store.expenseCategories.first else {
            return XCTFail("expected expense categories")
        }
        let selection = BillCategorySelection.from(
            type: .expense,
            categoryPath: group.name,
            expenseCategories: store.expenseCategories,
            incomeCategories: store.incomeCategories
        )
        XCTAssertEqual(selection.primaryId, group.id)
        XCTAssertNil(selection.secondaryId)
    }

    func testUnknownPathFallsBackToTypeOnly() {
        let selection = BillCategorySelection.from(
            type: .income,
            categoryPath: "不存在的分类-xxx",
            expenseCategories: store.expenseCategories,
            incomeCategories: store.incomeCategories
        )
        XCTAssertEqual(selection.type, .income)
        XCTAssertNil(selection.primaryId)
    }

    func testTransferSeedUsesExpenseBuckets() {
        let selection = BillCategorySelection.from(
            type: .expense,
            categoryPath: "转账",
            expenseCategories: store.expenseCategories,
            incomeCategories: store.incomeCategories
        )
        XCTAssertEqual(selection.type, .expense)
        XCTAssertNil(selection.primaryId)
    }
}
