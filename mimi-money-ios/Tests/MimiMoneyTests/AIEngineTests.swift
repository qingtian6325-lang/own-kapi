import XCTest
@testable import MimiMoneyCore

@MainActor
final class AIEngineTests: XCTestCase {
    // v1.2.1：本地 OCR 解析器已删除。以下用例把旧 OCR 时代的真实截图场景
    // 改用 Gemini 结构化结果（DTO）表达，验证同一条 DTO → 草稿换算路径。

    func testGeminiDraftForTNGEggetteScreenshot() {
        let dto = GeminiBillDTO(
            type: "expense",
            amount: 5.90,
            counterparty: "Near Me Voucher Eggette Lab",
            counterpartyKind: "merchant",
            account: "TNGewallet",
            primaryCategory: "餐饮",
            subCategory: "零食甜品",
            occurredAt: "2026-11-08 16:56",
            note: ""
        )
        let draft = dto.toDraftBill(now: Date())
        XCTAssertEqual(draft.amount, 5.90, accuracy: 0.001)
        XCTAssertTrue(draft.accountDisplayName.contains("TNG"))
        XCTAssertEqual(draft.categoryDisplayName, "餐饮-零食甜品")
        XCTAssertTrue(draft.merchantOrNote.contains("Near Me Voucher"))
    }

    func testGeminiDraftForYingLaiRestaurant() {
        let dto = GeminiBillDTO(
            type: "expense",
            amount: 38.99,
            counterparty: "YING LAI RESTAURANT",
            counterpartyKind: "merchant",
            account: "TNGewallet",
            primaryCategory: "餐饮",
            subCategory: "餐厅",
            occurredAt: "2026-11-10 20:07",
            note: ""
        )
        let draft = dto.toDraftBill(now: Date())
        XCTAssertEqual(draft.amount, 38.99, accuracy: 0.001)
        XCTAssertEqual(draft.type, .expense)
        XCTAssertEqual(draft.merchantOrNote, "YING LAI RESTAURANT 消费")
        XCTAssertEqual(draft.categoryDisplayName, "餐饮-餐厅")
        XCTAssertEqual(draft.accountDisplayName, "TNGewallet")

        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: draft.occurredAt)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 11)
        XCTAssertEqual(comps.day, 10)
        XCTAssertEqual(comps.hour, 20)
        XCTAssertEqual(comps.minute, 7)
    }

    func testGeminiDraftForDuitNowTransferToPerson() {
        let dto = GeminiBillDTO(
            type: "expense",
            amount: 150.0,
            counterparty: "TAN JING HAO",
            counterpartyKind: "person",
            account: "PBBank",
            primaryCategory: "资金往来",
            subCategory: "人情往来",
            occurredAt: "2026-11-08 21:59",
            note: ""
        )
        let draft = dto.toDraftBill(now: Date())
        XCTAssertEqual(draft.amount, 150.0, accuracy: 0.001)
        XCTAssertEqual(draft.accountDisplayName, "PBBank")
        XCTAssertEqual(draft.merchantOrNote, "转账给TAN JING HAO")

        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: draft.occurredAt)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 11)
        XCTAssertEqual(comps.day, 8)
        XCTAssertEqual(comps.hour, 21) // 9 PM -> 21
        XCTAssertEqual(comps.minute, 59)
    }

    func testRecognitionPromptDemandsDetailReading() {
        let prompt = GeminiClient.recognitionSystemPrompt(now: Date())
        XCTAssertTrue(prompt.contains("认真读细节"))
        XCTAssertTrue(prompt.contains("状态栏"))
        XCTAssertTrue(prompt.contains("收款方"))
        XCTAssertTrue(prompt.contains("参考号"))
        XCTAssertTrue(prompt.contains("不许用数字碎片"))
    }

    func testMultiBillNaturalLanguageSentenceSplitting() {
        let engine = MimiAIEngine()
        let bills = engine.parseNaturalLanguageBills("中午吃餐厅花了8.30，TNG打麻将输钱28，PBBank加油38.78")
        XCTAssertEqual(bills.count, 3)
        XCTAssertEqual(bills[0].amount, 8.30, accuracy: 0.001)
        XCTAssertEqual(bills[1].amount, 28.00, accuracy: 0.001)
        XCTAssertEqual(bills[1].accountDisplayName, "TNGewallet")
        XCTAssertEqual(bills[2].accountDisplayName, "PBBank")
        XCTAssertEqual(bills[2].amount, 38.78, accuracy: 0.001)
    }

    func testCategoryQuestionReturnsStandardCategoryTable() async {
        let store = MimiStore(inMemory: true)
        let engine = MimiAIEngine()
        let blocks = await engine.handleUserMessage("可以增加或删除某个分类吗？", in: store)
        XCTAssertTrue(blocks.contains(where: {
            if case .categoryTable = $0 { return true }
            return false
        }))
    }
}
