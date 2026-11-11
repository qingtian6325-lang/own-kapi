import XCTest
@testable import MimiMoneyCore

@MainActor
final class GeminiAndChatTests: XCTestCase {

// MARK: - Gemini 结构化输出 fixtures 解析

func testGeminiFixtureExpenseRestaurantTNG() throws {
// 模拟 Gemini generateContent 响应：candidates[0].content.parts[0].text 是结构化 JSON
let responseJSON = """
{"candidates":[{"content":{"parts":[{"text":"{\\"type\\":\\"expense\\",\\"amount\\":38.99,\\"counterparty\\":\\"YING LAI RESTAURANT\\",\\"counterpartyKind\\":\\"merchant\\",\\"account\\":\\"TNGewallet\\",\\"primaryCategory\\":\\"餐饮\\",\\"subCategory\\":\\"餐厅\\",\\"occurredAt\\":\\"2026-11-10 20:07\\",\\"note\\":\\"YING LAI RESTAURANT 消费\\"}"}]}}]}
"""
let dto = try decodeDTO(fromGenerateContentResponse: responseJSON)
let draft = dto.toDraftBill(now: Date())
XCTAssertEqual(draft.type,.expense)
XCTAssertEqual(draft.amount, 38.99, accuracy: 0.001)
XCTAssertEqual(draft.primaryCategoryId, "exp_food")
XCTAssertEqual(draft.subCategoryId, "exp_food_restaurant")
XCTAssertEqual(draft.categoryDisplayName, "餐饮-餐厅")
XCTAssertEqual(draft.accountId, "acc_tng")
XCTAssertEqual(draft.accountDisplayName, "TNGewallet")
XCTAssertEqual(draft.merchantOrNote, "YING LAI RESTAURANT 消费")

let cal = Calendar(identifier:.gregorian)
let comps = cal.dateComponents([.year,.month,.day,.hour,.minute], from: draft.occurredAt)
XCTAssertEqual(comps.year, 2026)
XCTAssertEqual(comps.month, 11)
XCTAssertEqual(comps.day, 10)
XCTAssertEqual(comps.hour, 20)
XCTAssertEqual(comps.minute, 7)
}

func testGeminiFixtureIncomeFromPersonUsesLocalNoteRule() throws {
// Gemini 没给备注时，本地按「{姓名} 转账」兜底生成
let dto = GeminiBillDTO(
type: "income",
amount: 150.0,
counterparty: "TAN JOO NI",
counterpartyKind: "person",
account: "PBBank",
primaryCategory: "别人转账",
subCategory: "",
occurredAt: "2026-11-08 21:59",
note: ""
)
let draft = dto.toDraftBill(now: Date())
XCTAssertEqual(draft.type,.income)
XCTAssertEqual(draft.primaryCategoryId, "inc_custom_transfer")
XCTAssertEqual(draft.accountId, "acc_pbb")
XCTAssertEqual(draft.merchantOrNote, "TAN JOO NI 转账")
}

func testGeminiFixtureExpenseToPersonNoteRuleAndCategory() throws {
let dto = GeminiBillDTO(
type: "expense",
amount: 200.0,
counterparty: "TAN JOO NI",
counterpartyKind: "person",
account: "TNGewallet",
primaryCategory: "资金往来",
subCategory: "人情往来",
occurredAt: "2026-11-09 12:00",
note: ""
)
let draft = dto.toDraftBill(now: Date())
XCTAssertEqual(draft.type,.expense)
XCTAssertEqual(draft.categoryDisplayName, "资金往来-人情往来")
XCTAssertEqual(draft.merchantOrNote, "转账给TAN JOO NI")
}

func testGeminiFixtureFuelStationCategory() throws {
let dto = GeminiBillDTO(
type: "expense",
amount: 38.78,
counterparty: "Petronas",
counterpartyKind: "merchant",
account: "PBBank",
primaryCategory: "交通",
subCategory: "加油充电",
occurredAt: "2026-11-05 08:30",
note: "Petronas 消费"
)
let draft = dto.toDraftBill(now: Date())
XCTAssertEqual(draft.primaryCategoryId, "exp_transport")
XCTAssertEqual(draft.subCategoryId, "exp_trans_fuel")
XCTAssertEqual(draft.categoryDisplayName, "交通-加油充电")
}

func testGeminiSchemaConstrainsCategoriesAndAccounts() {
let schema = GeminiClient.recognitionResponseSchema()
let properties = schema["properties"] as? [String: Any]
let primary = properties?["primaryCategory"] as? [String: Any]
let primaryEnum = primary?["enum"] as? [String] ?? []
XCTAssertTrue(primaryEnum.contains("餐饮"))
XCTAssertTrue(primaryEnum.contains("别人转账"))
let account = properties?["account"] as? [String: Any]
let accountEnum = account?["enum"] as? [String] ?? []
XCTAssertTrue(accountEnum.contains("TNGewallet"))
XCTAssertTrue(accountEnum.contains("PBBank"))
let typeProp = properties?["type"] as? [String: Any]
XCTAssertEqual(typeProp?["enum"] as? [String], ["expense", "income", "transfer"])
}

func testGeminiOccurredAtParsing() {
let parsed = GeminiBillDTO.parseOccurredAt("2026-11-10 20:07")
XCTAssertNotNil(parsed)
let cal = Calendar(identifier:.gregorian)
let comps = cal.dateComponents([.month,.day,.hour], from: parsed!)
XCTAssertEqual(comps.month, 11)
XCTAssertEqual(comps.day, 10)
XCTAssertEqual(comps.hour, 20)
XCTAssertNil(GeminiBillDTO.parseOccurredAt("不是日期"))
XCTAssertNil(GeminiBillDTO.parseOccurredAt(""))
}

// MARK: - 备注格式规则

func testNoteFormatterRules() {
XCTAssertEqual(
BillNoteFormatter.makeNote(type:.expense, counterparty: "YING LAI RESTAURANT", counterpartyKind: "merchant", modelNote: nil),
"YING LAI RESTAURANT 消费"
)
XCTAssertEqual(
BillNoteFormatter.makeNote(type:.expense, counterparty: "TAN JOO NI", counterpartyKind: "person", modelNote: nil),
"转账给TAN JOO NI"
)
XCTAssertEqual(
BillNoteFormatter.makeNote(type:.income, counterparty: "TAN JOO NI", counterpartyKind: "person", modelNote: nil),
"TAN JOO NI 转账"
)
XCTAssertEqual(
BillNoteFormatter.makeNote(type:.transfer, counterparty: "", counterpartyKind: "merchant", modelNote: nil),
"账户转账"
)
// Gemini 给了干净备注时优先用它
XCTAssertEqual(
BillNoteFormatter.makeNote(type:.expense, counterparty: "SHELL", counterpartyKind: "merchant", modelNote: "SHELL 加油"),
"SHELL 加油"
)
// 带杂讯的备注（百分比/超长）被本地规则替换
XCTAssertEqual(
BillNoteFormatter.makeNote(type:.expense, counterparty: "SHELL", counterpartyKind: "merchant", modelNote: "earn points (lunch 79%"),
"SHELL 消费"
)
XCTAssertFalse(BillNoteFormatter.isCleanNote("这一句备注实在是太长太长了远远超过三十个字的上限啊啊啊啊啊啊啊啊还不够长继续凑字数"))
XCTAssertTrue(BillNoteFormatter.isCleanNote("转账给TAN JOO NI"))
}

// MARK: - 金额合理性拦截

func testAmountSanityInterception() {
XCTAssertTrue(BillAmountSanity.isSuspicious(amount: 0))
XCTAssertTrue(BillAmountSanity.isSuspicious(amount: -12.5))
XCTAssertTrue(BillAmountSanity.isSuspicious(amount: 100_000.01))
XCTAssertFalse(BillAmountSanity.isSuspicious(amount: 100_000))
XCTAssertFalse(BillAmountSanity.isSuspicious(amount: 38.99))
// 状态栏电量百分比误读的真实案例
XCTAssertTrue(BillAmountSanity.isSuspicious(amount: 79, sourceText: "9:54 1 $ 79 (RM38.99)"))
XCTAssertTrue(BillAmountSanity.isSuspicious(amount: 85, sourceText: "电量 85% 信号"))
// 正文确有 RM79 交易时不误伤
XCTAssertFalse(BillAmountSanity.isSuspicious(amount: 79, sourceText: "Payment RM79.00 成功"))
XCTAssertFalse(BillAmountSanity.isSuspicious(amount: 50, sourceText: "午餐 RM50"))
}

// MARK: - 记账句 / 问账句判别

func testMessageClassifier() {
let engine = MimiAIEngine()
func kind(of message: String) -> BillMessageKind {
BillMessageClassifier.classify(message, draftCount: engine.parseNaturalLanguageBills(message).count)
}
XCTAssertEqual(kind(of: "午餐 38"),.billDraft)
XCTAssertEqual(kind(of: "打车 50 TNG"),.billDraft)
XCTAssertEqual(kind(of: "午饭 24.5 咖啡 12.9 打车 18"),.billDraft)
// Kapi 示例问题必须判为问账（即使里面有金额数字）
XCTAssertEqual(kind(of: "查询本月单笔消费超过200块的账单"),.question)
XCTAssertEqual(kind(of: "我本周支出最高的一笔是什么？"),.question)
XCTAssertEqual(kind(of: "我最近一次购物买了什么？"),.question)
XCTAssertEqual(kind(of: "这个月花了多少"),.question)
XCTAssertEqual(kind(of: "今天天气怎么样"),.question)
XCTAssertEqual(kind(of: "你好"),.question)
}

// MARK: - 聊天草稿确认才入账

func testChatDraftConfirmAndCancelFlow() {
let store = MimiStore(inMemory: true)
let engine = MimiAIEngine()
engine.clearHistory()
let countBefore = store.transactions.count

engine.handleUserMessage("午餐 38", store: store)
guard let draftMessage = engine.messages.last(where: { $0.hasDraftBills}) else {
XCTFail("记账句应生成草稿消息")
return
}
// 确认前不入账
XCTAssertEqual(store.transactions.count, countBefore)
engine.confirmDrafts(messageId: draftMessage.id, in: store)
XCTAssertEqual(store.transactions.count, countBefore + 1)
XCTAssertTrue(store.transactions.contains(where: { $0.amount == 38.0 && $0.categoryPath == "餐饮-餐厅" }))

engine.handleUserMessage("打车 50", store: store)
guard let secondDraft = engine.messages.last(where: { $0.hasDraftBills}) else {
XCTFail("第二句应生成草稿消息")
return
}
engine.cancelDrafts(messageId: secondDraft.id)
XCTAssertEqual(store.transactions.count, countBefore + 1)
engine.clearHistory()
}

// MARK: - Context 汇总数学

func testMonthlySummaryLinesMath() {
let now = DefaultCatalog.makeDate(year: 2026, month: 11, day: 15, hour: 12)
let txs: [TransactionItem] = [
TransactionItem(type:.expense, categoryPath: "餐饮-餐厅", amount: 100, accountName: "TNGewallet", note: "A", date: DefaultCatalog.makeDate(year: 2026, month: 11, day: 2)),
TransactionItem(type:.expense, categoryPath: "交通-加油充电", amount: 50.5, accountName: "PBBank", note: "B", date: DefaultCatalog.makeDate(year: 2026, month: 11, day: 3)),
TransactionItem(type:.expense, categoryPath: "餐饮-餐厅", amount: 999, accountName: "TNGewallet", note: "不计统计", includeInStats: false, date: DefaultCatalog.makeDate(year: 2026, month: 11, day: 4)),
TransactionItem(type:.income, categoryPath: "职业收入", amount: 2800, accountName: "PBBank", note: "工资", date: DefaultCatalog.makeDate(year: 2026, month: 11, day: 1)),
TransactionItem(type:.expense, categoryPath: "购物-生活用品", amount: 200, accountName: "CIMB", note: "C", date: DefaultCatalog.makeDate(year: 2026, month: 10, day: 20))
]
let lines = LedgerContextBuilder.monthlySummaryLines(transactions: txs, monthsBack: 6, now: now)
XCTAssertEqual(lines.count, 2)
XCTAssertTrue(lines[0].contains("2026年11月"))
XCTAssertTrue(lines[0].contains("RM150.50"))
XCTAssertTrue(lines[0].contains("RM2800.00"))
XCTAssertTrue(lines[0].contains("共 3 笔"))
XCTAssertTrue(lines[1].contains("2026年10月"))
XCTAssertTrue(lines[1].contains("RM200.00"))
}

func testRelevantTransactionsCapAndKeywordPriority() {
let now = DefaultCatalog.makeDate(year: 2026, month: 11, day: 15, hour: 12)
var txs: [TransactionItem] = []
for index in 0..<40 {
txs.append(TransactionItem(
type:.expense,
categoryPath: "购物-生活用品",
amount: Double(index + 1),
accountName: "TNGewallet",
note: "购物\(index)",
date: DefaultCatalog.makeDate(year: 2026, month: 11, day: 1 + (index % 14), hour: 10)
))
}
txs.append(TransactionItem(
type:.expense,
categoryPath: "餐饮-餐厅",
amount: 88,
accountName: "TNGewallet",
note: "大餐",
date: DefaultCatalog.makeDate(year: 2026, month: 9, day: 1)
))
let capped = LedgerContextBuilder.relevantTransactions(from: txs, question: "随便问问", now: now)
XCTAssertEqual(capped.count, LedgerContextBuilder.maxRecentRecords)

let matched = LedgerContextBuilder.relevantTransactions(from: txs, question: "我最近一次餐饮买了什么", now: now)
XCTAssertEqual(matched.first?.categoryPath, "餐饮-餐厅")
}

func testBuildContextStructureAndCap() {
let store = MimiStore(inMemory: true)
let context = LedgerContextBuilder.buildContext(store: store, question: "本月花了多少", now: Date())
XCTAssertTrue(context.contains("【月度收支汇总（近6个月）】"))
XCTAssertTrue(context.contains("【账户余额】"))
XCTAssertTrue(context.contains("【预算】"))
XCTAssertLessThanOrEqual(context.count, LedgerContextBuilder.maxCharacters + 32)
}

// MARK: - Helpers

private func decodeDTO(fromGenerateContentResponse jsonText: String) throws -> GeminiBillDTO {
let data = Data(jsonText.utf8)
let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
let candidates = object?["candidates"] as? [[String: Any]]
let content = candidates?.first?["content"] as? [String: Any]
let parts = content?["parts"] as? [[String: Any]]
let text = parts?.first?["text"] as? String
guard let text else {
XCTFail("fixture 响应缺少 text")
throw GeminiError.emptyResponse
}
return try JSONDecoder().decode(GeminiBillDTO.self, from: Data(text.utf8))
}
}
