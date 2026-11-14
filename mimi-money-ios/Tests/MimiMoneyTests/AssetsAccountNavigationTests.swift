import XCTest
@testable import MimiMoneyCore

/// Regression: account detail left/right/left must not dump the user onto 记账 (home).
final class AssetsAccountNavigationTests: XCTestCase {
    func testEditAccountSheetRouteIdentityUsesAccountId() {
        let route = EditAccountSheetRoute(accountId: "acc_cash")
        XCTAssertEqual(route.id, "acc_cash")
        // sheet(item:) requires stable Identifiable id — never present via Bool + optional unwrap.
        XCTAssertEqual(
            EditAccountSheetRoute(accountId: "acc_tng"),
            EditAccountSheetRoute(accountId: "acc_tng")
        )
    }

    func testBackFromAccountDetailPopsOnlyDetailNotAssetsOverlay() {
        var state = AssetsAccountNavigationState(
            isAssetsPresented: true,
            selectedAccountID: "acc_tng"
        )

        let effect = state.apply(.back)

        XCTAssertEqual(state.selectedAccountID, nil)
        XCTAssertTrue(state.isAssetsPresented)
        XCTAssertFalse(effect.dismissAssetsOverlay)
    }

    func testBackFromAssetsRootDismissesOverlayToHome() {
        var state = AssetsAccountNavigationState(isAssetsPresented: true)

        let effect = state.apply(.back)

        XCTAssertFalse(state.isAssetsPresented)
        XCTAssertTrue(effect.dismissAssetsOverlay)
    }

    /// left (back) → right (re-open account) → left (back) stays on 资产, never 记账/home.
    func testLeftRightLeftAccountDrillDoesNotDismissAssets() {
        var state = AssetsAccountNavigationState(isAssetsPresented: true)

        _ = state.apply(.openAccount("acc_a"))
        XCTAssertEqual(state.selectedAccountID, "acc_a")

        var effect = state.apply(.back) // left
        XCTAssertNil(state.selectedAccountID)
        XCTAssertFalse(effect.dismissAssetsOverlay)

        _ = state.apply(.openAccount("acc_b")) // right / re-enter
        XCTAssertEqual(state.selectedAccountID, "acc_b")

        effect = state.apply(.back) // left again
        XCTAssertNil(state.selectedAccountID)
        XCTAssertTrue(state.isAssetsPresented)
        XCTAssertFalse(effect.dismissAssetsOverlay)
    }

    func testBackWhileEntrySheetOpenDismissesSheetFirstKeepsAccount() {
        let expenseID = UUID()
        var state = AssetsAccountNavigationState(
            isAssetsPresented: true,
            selectedAccountID: "acc_tng",
            entryRoute: .expense(accountName: "TNG", presentationID: expenseID)
        )

        let effect = state.apply(.back)

        XCTAssertEqual(state.selectedAccountID, "acc_tng")
        XCTAssertNil(state.entryRoute)
        XCTAssertTrue(state.isAssetsPresented)
        XCTAssertFalse(effect.dismissAssetsOverlay)
    }

    /// 记账 (left pill) → 转账 (right) → 记账 (left) keeps account + sheet identity in sync.
    func testExpenseTransferExpenseEntryRouteNeverClearsAccount() {
        var state = AssetsAccountNavigationState(
            isAssetsPresented: true,
            selectedAccountID: "acc_tng"
        )

        _ = state.apply(.openEntry(.expense(accountName: "TNG")))
        XCTAssertEqual(state.entryRoute?.transactionType, .expense)
        XCTAssertEqual(state.entryRoute?.accountName, "TNG")
        XCTAssertEqual(state.selectedAccountID, "acc_tng")

        _ = state.apply(.dismissEntry)
        XCTAssertNil(state.entryRoute)
        XCTAssertEqual(state.selectedAccountID, "acc_tng")

        _ = state.apply(.openEntry(.transfer(accountName: "TNG")))
        XCTAssertEqual(state.entryRoute?.transactionType, .transfer)
        XCTAssertEqual(state.entryRoute?.accountName, "TNG")
        XCTAssertEqual(state.selectedAccountID, "acc_tng")

        _ = state.apply(.dismissEntry)
        _ = state.apply(.openEntry(.expense(accountName: "TNG")))
        XCTAssertEqual(state.entryRoute?.transactionType, .expense)
        XCTAssertEqual(state.selectedAccountID, "acc_tng")
        XCTAssertTrue(state.isAssetsPresented)
    }

    func testOpenEntryWhileAnotherEntryOpenReplacesRouteWithoutPoppingAccount() {
        var state = AssetsAccountNavigationState(
            isAssetsPresented: true,
            selectedAccountID: "acc_cimb",
            entryRoute: .expense(accountName: "CIMB", presentationID: UUID())
        )

        _ = state.apply(.openEntry(.transfer(accountName: "CIMB")))

        XCTAssertEqual(state.entryRoute?.transactionType, .transfer)
        XCTAssertEqual(state.entryRoute?.accountName, "CIMB")
        XCTAssertEqual(state.selectedAccountID, "acc_cimb")
    }

    /// 转账 button must open transfer tab; 记账 → expense. Fresh presentationID every open.
    func testTransferEntryRouteIntendedTabIsTransfer() {
        let transfer = AssetsAccountNavigationState.AccountEntryRoute.transfer(accountName: "现金")
        let expense = AssetsAccountNavigationState.AccountEntryRoute.expense(accountName: "现金")
        XCTAssertEqual(transfer.transactionType, .transfer)
        XCTAssertEqual(expense.transactionType, .expense)
        XCTAssertNotEqual(transfer.id, expense.id)
    }

    func testEachEntryOpenGetsUniquePresentationIdentity() {
        let a = AssetsAccountNavigationState.AccountEntryRoute.transfer(accountName: "TNG")
        let b = AssetsAccountNavigationState.AccountEntryRoute.transfer(accountName: "TNG")
        XCTAssertNotEqual(a.presentationID, b.presentationID)
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(a.transactionType, b.transactionType)
        XCTAssertEqual(a.accountName, b.accountName)
    }
}
