import XCTest
@testable import KapiMoneyCore

@MainActor
final class ShortcutIntentTests: XCTestCase {
    func testShortcutRecognizeAndConfirmSavesDirectly() {
        let store = KapiStore(inMemory: true)
        let initialCount = store.transactions.count
        let draft = ReceiptOCRService.parseReceiptText("-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34")
        let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
        XCTAssertEqual(store.transactions.count, initialCount + 1)
        XCTAssertEqual(saved.amount, 5.90, accuracy: 0.001)
        XCTAssertNil(store.pendingEditTransactionId)
    }

    func testShortcutModifyButtonDeepLinksIntoAppBillEditor() {
        let store = KapiStore(inMemory: true)
        let draft = ReceiptOCRService.parseReceiptText("-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab")
        let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
        let url = ShortcutActionCoordinator.markForInAppModification(transactionId: saved.id, in: store)
        XCTAssertEqual(url.absoluteString, "kapimoney://edit-bill?id=\(saved.id.uuidString)")

        store.pendingEditTransactionId = nil
        let handled = ShortcutActionCoordinator.handleIncomingURL(url, in: store)
        XCTAssertTrue(handled)
        XCTAssertEqual(store.pendingEditTransactionId, saved.id)
    }

    func testQuickScanURLSchemeWithRealParameters() {
        let store = KapiStore(inMemory: true)
        let initialCount = store.transactions.count
        let url = URL(string: "kapimoney://quick-scan?amount=25.00&note=Starbucks&account=CIMB")!
        let handled = ShortcutActionCoordinator.handleIncomingURL(url, in: store)
        XCTAssertTrue(handled)
        XCTAssertEqual(store.transactions.count, initialCount + 1)
        XCTAssertEqual(store.pendingShortcutSnippetBill?.amount, 25.00, accuracy: 0.001)
        XCTAssertEqual(store.pendingShortcutSnippetBill?.accountName, "CIMB")
    }

    func testQuickScanURLSchemeWithOCRText() {
        let store = KapiStore(inMemory: true)
        let raw = "-RM38.78\nPayment - PBB\nPetronas Gas\n08/11/2026".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = URL(string: "kapimoney://quick-scan?text=\(raw)")!
        let handled = ShortcutActionCoordinator.handleIncomingURL(url, in: store)
        XCTAssertTrue(handled)
        XCTAssertEqual(store.pendingShortcutSnippetBill?.amount, 38.78, accuracy: 0.001)
        XCTAssertEqual(store.pendingShortcutSnippetBill?.accountName, "PBBank")
    }
}
