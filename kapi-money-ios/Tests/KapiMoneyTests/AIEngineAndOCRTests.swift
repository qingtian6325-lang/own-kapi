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
        XCTAssertEqual(draft.accountDisplayName, "TNGewallet")
        XCTAssertEqual(draft.categoryDisplayName, "餐饮-零食甜品")
        XCTAssertTrue(draft.merchantOrNote.contains("Near Me Voucher"))
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
