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
