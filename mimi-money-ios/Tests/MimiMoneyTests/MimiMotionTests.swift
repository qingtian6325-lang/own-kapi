import XCTest
@testable import MimiMoneyCore

final class MimiMotionTests: XCTestCase {
    func testHandoffDelaysAreSnappyNotHalfBeatLate() {
        // Primary taps should not wait ~0.3s before the next surface moves.
        XCTAssertLessThanOrEqual(MimiMotion.pageDuration, 0.20)
        XCTAssertLessThanOrEqual(MimiMotion.sheetDuration, 0.18)
        XCTAssertLessThanOrEqual(MimiMotion.drawerDuration, 0.18)
        XCTAssertLessThanOrEqual(MimiMotion.handoffDelay(.page, reduceMotion: false), 0.16)
        XCTAssertLessThanOrEqual(MimiMotion.handoffDelay(.sheet, reduceMotion: false), 0.14)
        XCTAssertLessThanOrEqual(MimiMotion.handoffDelay(.drawer, reduceMotion: false), 0.14)
        XCTAssertLessThanOrEqual(MimiMotion.handoffDelay(.page, reduceMotion: true), 0.06)
    }
}

@MainActor
final class SnappyDeleteTransactionTests: XCTestCase {
    func testDeleteRemovesRowImmediatelyBeforePersist() {
        let store = MimiStore(inMemory: true)
        store.resetToCleanEmpty()
        let tx = TransactionItem(
            type: .expense,
            categoryPath: "餐饮-餐厅",
            amount: 12.5,
            accountName: "TNGewallet"
        )
        store.addTransaction(tx)
        XCTAssertEqual(store.transactions.count, 1)

        store.deleteTransaction(id: tx.id)
        // List must update on the same call — not after disk / full reconcile.
        XCTAssertTrue(store.transactions.isEmpty)
        XCTAssertFalse(store.transactions.contains(where: { $0.id == tx.id }))
    }
}
