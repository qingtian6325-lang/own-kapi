import XCTest
@testable import MimiMoneyCore

final class BookkeepingSheetSwipePolicyTests: XCTestCase {
    func testHorizontalDominantBlocksDiagonalSheetDismissSteal() {
        // Left swipe on leftmost 支出 (mostly horizontal, small vertical) → paging, not dismiss.
        XCTAssertTrue(BookkeepingSheetSwipePolicy.isHorizontalDominant(dx: -60, dy: 20))
        XCTAssertFalse(BookkeepingSheetSwipePolicy.isVerticalDominant(dx: -60, dy: 20))
    }

    func testVerticalDominantAllowsSheetDismiss() {
        XCTAssertTrue(BookkeepingSheetSwipePolicy.isVerticalDominant(dx: 10, dy: 80))
        XCTAssertFalse(BookkeepingSheetSwipePolicy.isHorizontalDominant(dx: 10, dy: 80))
    }

    func testNeighborFromExpenseSwipeLeftGoesIncome() {
        XCTAssertEqual(
            BookkeepingSheetSwipePolicy.neighbor(of: .expense, dx: -50),
            .income
        )
    }

    func testNeighborFromExpenseSwipeRightIsNil() {
        XCTAssertNil(BookkeepingSheetSwipePolicy.neighbor(of: .expense, dx: 50))
    }

    func testNeighborTransferAndIncomeBothDirections() {
        XCTAssertEqual(BookkeepingSheetSwipePolicy.neighbor(of: .income, dx: -50), .transfer)
        XCTAssertEqual(BookkeepingSheetSwipePolicy.neighbor(of: .income, dx: 50), .expense)
        XCTAssertEqual(BookkeepingSheetSwipePolicy.neighbor(of: .transfer, dx: 50), .income)
        XCTAssertNil(BookkeepingSheetSwipePolicy.neighbor(of: .transfer, dx: -50))
    }

    func testTabOrderIsExpenseIncomeTransfer() {
        XCTAssertEqual(
            BookkeepingSheetSwipePolicy.tabOrder,
            [.expense, .income, .transfer]
        )
    }
}
