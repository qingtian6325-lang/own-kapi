import XCTest
@testable import KapiMoneyCore

@MainActor
final class AIEngineAndOCRTests: XCTestCase {
    func testParseTNGeWalletScreenshotTextIgnoresWalletRefNumbers() {
        let rawOCR = """
        -RM5.90
        Near Me Voucher Eggette Lab
        Payment Details Payment - TNGD
        Payment Method eWallet Balance
        Date/Time 08/11/2026 16:56:34
        Wallet Ref 2026110810110000010000TNGOW3MY171298463015729
        Status Successful
        Transaction No. 202611081656326680004726107380
        """
        let draft = ReceiptOCRService.parseReceiptText(rawOCR)
        XCTAssertEqual(draft.amount, 5.90, accuracy: 0.001)
        XCTAssertTrue(draft.accountDisplayName.contains("TNG"))
        XCTAssertEqual(draft.categoryDisplayName, "餐饮-零食甜品")
        XCTAssertTrue(draft.merchantOrNote.contains("Near Me Voucher"))
    }

    func testTransferReceiptRecipientAndDateExtraction() {
        let transferOCR = """
        DuitNow Transfer
        Transfer to: TAN JING HAO
        Amount: RM 150.00
        From: Public Bank PBBank
        Date & Time: 08 Nov 2026, 09:59 PM
        Reference ID: 20261108998877112233
        Status: Successful
        """
        let draft = ReceiptOCRService.parseReceiptText(transferOCR)
        XCTAssertEqual(draft.amount, 150.0, accuracy: 0.001)
        XCTAssertEqual(draft.accountDisplayName, "PBBank")
        XCTAssertEqual(draft.merchantOrNote, "TAN JING HAO")

        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: draft.occurredAt)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 11)
        XCTAssertEqual(comps.day, 8)
        XCTAssertEqual(comps.hour, 21) // 9 PM -> 21
        XCTAssertEqual(comps.minute, 59)
    }

    func testMultiBillNaturalLanguageSentenceSplitting() {
        let engine = KapiAIEngine()
        let bills = engine.parseNaturalLanguageBills("中午吃餐厅花了8.30，TNG打麻将输钱28，PBBank加油38.78")
        XCTAssertEqual(bills.count, 3)
        XCTAssertEqual(bills[0].amount, 8.30, accuracy: 0.001)
        XCTAssertEqual(bills[1].amount, 28.00, accuracy: 0.001)
        XCTAssertEqual(bills[1].accountDisplayName, "TNGewallet")
        XCTAssertEqual(bills[2].amount, 38.78, accuracy: 0.001)
        XCTAssertEqual(bills[2].accountDisplayName, "PBBank")
    }

    func testCategoryQuestionReturnsStandardCategoryTable() async {
        let store = KapiStore(inMemory: true)
        let engine = KapiAIEngine()
        let blocks = await engine.handleUserMessage("可以增加或删除某个分类吗？", in: store)
        XCTAssertTrue(blocks.contains(where: {
            if case .categoryTable = $0 { return true }
            return false
        }))
    }
}
