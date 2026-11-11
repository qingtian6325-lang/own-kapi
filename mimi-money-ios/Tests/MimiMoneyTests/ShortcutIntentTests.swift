import XCTest
@testable import MimiMoneyCore

@MainActor
final class ShortcutIntentTests: XCTestCase {
    func testShortcutRecognizeAndConfirmSavesDirectly() {
        let store = MimiStore(inMemory: true)
        let initialCount = store.transactions.count
        let draft = ReceiptOCRService.parseReceiptText("-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34")
        let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
        XCTAssertEqual(store.transactions.count, initialCount + 1)
        XCTAssertEqual(saved.amount, 5.90, accuracy: 0.001)
        XCTAssertNil(store.pendingEditTransactionId)
    }

    func testShortcutModifyButtonDeepLinksIntoAppBillEditor() {
        let store = MimiStore(inMemory: true)
        let draft = ReceiptOCRService.parseReceiptText("-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab")
        let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
        let url = ShortcutActionCoordinator.markForInAppModification(transactionId: saved.id, in: store)
        XCTAssertEqual(url.absoluteString, "mimimoney://edit-bill?id=\(saved.id.uuidString)")

        store.pendingEditTransactionId = nil
        let handled = ShortcutActionCoordinator.handleIncomingURL(url, in: store)
        XCTAssertTrue(handled)
        XCTAssertEqual(store.pendingEditTransactionId, saved.id)
    }

    func testQuickScanURLSchemeWithRealParameters() {
        let store = MimiStore(inMemory: true)
        let initialCount = store.transactions.count
        let url = URL(string: "mimimoney://quick-scan?amount=25.00&note=Starbucks&account=CIMB")!
        let handled = ShortcutActionCoordinator.handleIncomingURL(url, in: store)
        XCTAssertTrue(handled)
        XCTAssertEqual(store.transactions.count, initialCount + 1)
        XCTAssertEqual(store.pendingShortcutSnippetBill?.amount ?? 0.0, 25.00, accuracy: 0.001)
        XCTAssertEqual(store.pendingShortcutSnippetBill?.accountName, "CIMB")
    }

    // MARK: - v1.1.2 确认型流程：暂存 → 确认才落盘 / 修改转编辑 / 单次消费幂等

    func testStagePendingScanDoesNotRecordUntilFinalized() {
        let store = MimiStore(inMemory: true)
        let initialCount = store.transactions.count
        let tngBefore = store.accounts.first(where: { $0.id == "acc_tng" })?.balance ?? 0
        let draft = ReceiptOCRService.parseReceiptText("-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34")

        let staged = ShortcutActionCoordinator.stageRecognizedDraft(draft, in: store)
        XCTAssertFalse(staged.isConfirmed)
        XCTAssertEqual(store.transactions.count, initialCount, "暂存阶段不应落盘")
        XCTAssertEqual(store.pendingScanTransactions.count, 1)
        let tngStaged = store.accounts.first(where: { $0.id == "acc_tng" })?.balance ?? 0
        XCTAssertEqual(tngStaged, tngBefore, accuracy: 0.001, "暂存阶段不应影响余额")

        let finalized = ShortcutActionCoordinator.finalizePendingScan(id: staged.id, in: store)
        XCTAssertNotNil(finalized)
        XCTAssertEqual(finalized?.isConfirmed, true)
        XCTAssertEqual(store.transactions.count, initialCount + 1)
        XCTAssertEqual(store.pendingScanTransactions.count, 0)
        let tngAfter = store.accounts.first(where: { $0.id == "acc_tng" })?.balance ?? 0
        XCTAssertEqual(tngAfter, tngBefore - 5.90, accuracy: 0.001, "落盘后余额才扣款")
    }

    func testFinalizePendingScanIsIdempotent() {
        let store = MimiStore(inMemory: true)
        let initialCount = store.transactions.count
        let draft = ReceiptOCRService.parseReceiptText("-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34")
        let staged = ShortcutActionCoordinator.stageRecognizedDraft(draft, in: store)

        XCTAssertNotNil(ShortcutActionCoordinator.finalizePendingScan(id: staged.id, in: store))
        XCTAssertNil(ShortcutActionCoordinator.finalizePendingScan(id: staged.id, in: store), "第二次消费必须返回 nil")
        XCTAssertEqual(store.transactions.count, initialCount + 1, "绝不重复记账")
    }

    func testConsumePendingScanForEditRecordsUnconfirmedAndDeepLinks() {
        let store = MimiStore(inMemory: true)
        let initialCount = store.transactions.count
        let draft = ReceiptOCRService.parseReceiptText("-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34")
        let staged = ShortcutActionCoordinator.stageRecognizedDraft(draft, in: store)

        let editing = ShortcutActionCoordinator.consumePendingScanForEdit(id: staged.id, in: store)
        XCTAssertNotNil(editing)
        XCTAssertEqual(editing?.isConfirmed, false, "修改路径转入的记录保持未确认")
        XCTAssertEqual(store.transactions.count, initialCount + 1)
        XCTAssertEqual(store.pendingEditTransactionId, staged.id)
        XCTAssertEqual(store.pendingScanTransactions.count, 0)

        // 重复点「修改」：不重复记账，只重新定位
        let again = ShortcutActionCoordinator.consumePendingScanForEdit(id: staged.id, in: store)
        XCTAssertNotNil(again)
        XCTAssertEqual(store.transactions.count, initialCount + 1)
        // 修改路径消费后，确认路径不得再落盘一笔
        XCTAssertNil(ShortcutActionCoordinator.finalizePendingScan(id: staged.id, in: store))
        XCTAssertEqual(store.transactions.count, initialCount + 1)
    }

    func testDiscardPendingScanNeverRecords() {
        let store = MimiStore(inMemory: true)
        let initialCount = store.transactions.count
        let draft = ReceiptOCRService.parseReceiptText("-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34")
        let staged = ShortcutActionCoordinator.stageRecognizedDraft(draft, in: store)
        store.discardPendingScan(id: staged.id)
        XCTAssertEqual(store.pendingScanTransactions.count, 0)
        XCTAssertNil(ShortcutActionCoordinator.finalizePendingScan(id: staged.id, in: store))
        XCTAssertEqual(store.transactions.count, initialCount)
    }

    func testQuickScanURLSchemeWithOCRText() {
        let store = MimiStore(inMemory: true)
        let raw = "-RM38.78\nPayment - PBB\nPetronas Gas\n08/11/2026".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = URL(string: "mimimoney://quick-scan?text=\(raw)")!
        let handled = ShortcutActionCoordinator.handleIncomingURL(url, in: store)
        XCTAssertTrue(handled)
        XCTAssertEqual(store.pendingShortcutSnippetBill?.amount ?? 0.0, 38.78, accuracy: 0.001)
        XCTAssertEqual(store.pendingShortcutSnippetBill?.accountName, "PBBank")
    }
}
