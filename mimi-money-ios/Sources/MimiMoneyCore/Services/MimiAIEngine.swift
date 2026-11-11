import Foundation
import Combine

public struct AICategoryTableRow: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let primaryCategory: String
    public let subcategoriesText: String

    public init(id: UUID = UUID(), primaryCategory: String, subcategoriesText: String) {
        self.id = id
        self.primaryCategory = primaryCategory
        self.subcategoriesText = subcategoriesText
    }
}

public enum AIChatResponseBlock: Equatable, Sendable {
    case text(String)
    case draftBills([ParsedDraftBill])
    case categoryTable(expenseRows: [(String, String)], incomeRows: [(String, String)], customNote: String)
    case spendingSummary(title: String, amount: Double, count: Int, details: String)

    public static func recognizedBills(_ drafts: [ParsedDraftBill]) -> AIChatResponseBlock {
        .draftBills(drafts)
    }

    public static func == (lhs: AIChatResponseBlock, rhs: AIChatResponseBlock) -> Bool {
        switch (lhs, rhs) {
        case let (.text(a), .text(b)):
            return a == b
        case let (.draftBills(a), .draftBills(b)):
            return a == b
        case let (.categoryTable(ea, ia, na), .categoryTable(eb, ib, nb)):
            return ea.map(\.0) == eb.map(\.0) && ia.map(\.0) == ib.map(\.0) && na == nb
        case let (.spendingSummary(ta, aa, ca, da), .spendingSummary(tb, ab, cb, db)):
            return ta == tb && abs(aa - ab) < 0.001 && ca == cb && da == db
        default:
            return false
        }
    }
}

public typealias AIChatMessage = AIChatMessageItem

public struct AIChatMessageItem: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var isUser: Bool
    public var userText: String
    public var blocks: [AIChatResponseBlock]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        isUser: Bool,
        userText: String = "",
        blocks: [AIChatResponseBlock] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.isUser = isUser
        self.userText = userText
        self.blocks = blocks
        self.createdAt = createdAt
    }

    public var hasDraftBills: Bool {
        blocks.contains(where: { block in
            if case .draftBills = block { return true }
            return false
        })
    }

    public var draftBills: [ParsedDraftBill] {
        blocks.flatMap { block -> [ParsedDraftBill] in
            if case .draftBills(let drafts) = block { return drafts }
            return []
        }
    }
}

@MainActor
public final class MimiAIEngine: ObservableObject {
    @Published public var messages: [AIChatMessageItem] = []

    // 旧版自定义大模型设置（保留兼容，v1.2.0 起识别/问账统一走 Gemini 设置）
    @Published public var apiKey: String = UserDefaults.standard.string(forKey: "mimi_llm_api_key") ?? ""
    @Published public var apiBaseURL: String = UserDefaults.standard.string(forKey: "mimi_llm_base_url") ?? "https://api.deepseek.com/v1"
    @Published public var apiModel: String = UserDefaults.standard.string(forKey: "mimi_llm_model") ?? "deepseek-chat"

    public var customAPIKey: String {
        get { apiKey }
        set { apiKey = newValue }
    }

    public var customAPIBaseURL: String {
        get { apiBaseURL }
        set { apiBaseURL = newValue }
    }

    public static let presetPromptChips: [String] = [
        "可以增加或删除某个分类吗？",
        "怎样获得更多VIP时长？",
        "怎样加入共享账本？"
    ]

    /// Kapi 式示例问题气泡（点即发送）
    public static let exampleQuestions: [String] = [
        "查询本月单笔消费超过200块的账单",
        "我本周支出最高的一笔是什么？",
        "我最近一次购物买了什么？"
    ]

    public init() {
        loadHistory()
    }

    public func saveAPISettings(key: String, baseURL: String, model: String) {
        self.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(self.apiKey, forKey: "mimi_llm_api_key")
        UserDefaults.standard.set(self.apiBaseURL, forKey: "mimi_llm_base_url")
        UserDefaults.standard.set(self.apiModel, forKey: "mimi_llm_model")
    }

    // MARK: - Natural Language Bill Parsing

    /// Splits a single natural-language input into one or more `ParsedDraftBill` items ("一句话记多笔").
    /// Supports both punctuation delimiters ("，,；;\n") and whitespace between an amount and the next keyword (e.g. "午饭 24.5 咖啡 12.9 打车 18").
    public func parseNaturalLanguageBills(_ input: String, now: Date = Date()) -> [ParsedDraftBill] {
        let normalized = input.replacingOccurrences(
            of: #"([0-9]+(?:\.[0-9]{1,2})?(?:\s*(?:元|块|令吉))?)\s+(?=[^\s0-9\.])"#,
            with: "$1,",
            options: .regularExpression
        )
        let separators = CharacterSet(charactersIn: "，,；;\n")
        let rawClauses = normalized
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var drafts: [ParsedDraftBill] = []
        for clause in rawClauses {
            guard let amount = extractAmount(from: clause), amount > 0 else { continue }
            let isIncome = clause.contains("收") || clause.contains("工资") || clause.contains("还我") || clause.contains("还钱") || clause.contains("奖金")
            let (accountId, accountName) = detectAccount(in: clause)
            let (primaryId, subId, categoryDisplay) = detectCategory(in: clause, isIncome: isIncome)
            let cleanNote = cleanClauseNote(clause)
            drafts.append(
                ParsedDraftBill(
                    type: isIncome ? .income : .expense,
                    amount: amount,
                    currency: .myr,
                    primaryCategoryId: primaryId,
                    subCategoryId: subId,
                    categoryDisplayName: categoryDisplay,
                    accountId: accountId,
                    accountDisplayName: accountName,
                    merchantOrNote: cleanNote,
                    occurredAt: detectRelativeDate(in: clause, now: now)
                )
            )
        }
        return drafts
    }

    // MARK: - Chat Flow (UI 入口)

    /// 聊天发送主流程：
    /// 1. 明确记账句 → 生成草稿卡（确认才入账）
    /// 2. 本地可答的问题（分类表/退款/报销/本月汇总）→ 离线直接答
    /// 3. 其余问账 → 带账目上下文问 Gemini；无 key/无网时在聊天里明说不可用，不编答案
    public func handleUserMessage(_ message: String, store: MimiStore) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(
            AIChatMessageItem(isUser: true, userText: trimmed, blocks: [.text(trimmed)])
        )

        let drafts = parseNaturalLanguageBills(trimmed)
        if BillMessageClassifier.classify(trimmed, draftCount: drafts.count) == .billDraft {
            messages.append(
                AIChatMessageItem(isUser: false, userText: "", blocks: [
                    .text("小金主，咪咪已为你识别出 \(drafts.count) 笔账单草稿，核对无误后点「确认记账」才会入账："),
                    .draftBills(drafts)
                ])
            )
            saveHistory()
            return
        }

        if let local = localAnswerBlocks(for: trimmed, in: store) {
            messages.append(AIChatMessageItem(isUser: false, userText: "", blocks: local))
            saveHistory()
            return
        }

        guard GeminiSettings.hasAPIKey else {
            messages.append(
                AIChatMessageItem(isUser: false, userText: "", blocks: [
                    .text("小金主，这个问题要联网查账才能答：请先到「设置 → AI 识别引擎」填入你的 Gemini API Key（在 Google AI Studio 免费申请），填好后就能问我「本月单笔超过 200 的账单」「本周最贵的一笔」这类问题了 🐱")
                ])
            )
            saveHistory()
            return
        }

        let placeholder = AIChatMessageItem(isUser: false, userText: "", blocks: [.text("咪咪正在翻账本…")])
        messages.append(placeholder)
        saveHistory()
        let placeholderId = placeholder.id
        Task { [weak self] in
            guard let self else { return }
            do {
                let answer = try await GeminiClient.answerQuestion(trimmed, store: store)
                GeminiSettings.recordCallStatus(success: true, message: "问账成功（Gemini）")
                self.replaceMessageBlocks(id: placeholderId, blocks: [.text(answer)])
            } catch {
                let reason = (error as? GeminiError)?.description ?? error.localizedDescription
                GeminiSettings.recordCallStatus(success: false, message: "问账失败：\(reason)")
                self.replaceMessageBlocks(id: placeholderId, blocks: [
                    .text("问账暂时不可用：\(reason)。请检查网络，或到「设置 → AI 识别引擎」点测试连接；也可以直接问我「有哪些分类」「这个月花了多少」，或用一句话记账（如：午餐 38）。")
                ])
            }
            self.saveHistory()
        }
    }

    /// 兼容旧调用：只返回本地应答块（分类表/本地汇总/记账草稿/兜底提示），不发网络请求。
    public func handleUserMessage(_ message: String, in store: MimiStore) async -> [AIChatResponseBlock] {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return buildReplyBlocks(for: trimmed, in: store)
    }

    // MARK: - Draft Confirm / Cancel（确认才入账）

    public func confirmDrafts(messageId: UUID, in store: MimiStore) {
        guard let idx = messages.firstIndex(where: { $0.id == messageId }) else { return }
        let drafts = messages[idx].draftBills
        guard !drafts.isEmpty else { return }
        var summaries: [String] = []
        for draft in drafts {
            let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
            summaries.append("\(saved.categoryPath) \(MimiTheme.formatRM(saved.amount))")
        }
        messages[idx].blocks = [.text("✅ 已记账：\(summaries.joined(separator: "；"))")]
        saveHistory()
    }

    public func cancelDrafts(messageId: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == messageId }) else { return }
        guard messages[idx].hasDraftBills else { return }
        messages[idx].blocks = [.text("已取消，这笔草稿没有入账。")]
        saveHistory()
    }

    /// 相册/拍照识别出的草稿进入聊天，同样走确认才入账。
    public func appendRecognizedDraft(_ draft: ParsedDraftBill, sourceLabel: String) {
        messages.append(
            AIChatMessageItem(isUser: false, userText: "", blocks: [
                .text("小金主，已从\(sourceLabel)识别出这笔账单草稿，核对无误后点「确认记账」才会入账："),
                .draftBills([draft])
            ])
        )
        saveHistory()
    }

    private func replaceMessageBlocks(id: UUID, blocks: [AIChatResponseBlock]) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].blocks = blocks
    }

    // MARK: - Local Answers

    private func buildReplyBlocks(for trimmed: String, in store: MimiStore) -> [AIChatResponseBlock] {
        if let local = localAnswerBlocks(for: trimmed, in: store) {
            return local
        }
        let drafts = parseNaturalLanguageBills(trimmed)
        if !drafts.isEmpty {
            return [
                .text("小金主，咪咪已为你识别并拆分出 \(drafts.count) 笔账单，点击下方确认即可入账："),
                .draftBills(drafts)
            ]
        }
        return [
            .text("你可以直接对我说“今天午饭吃餐厅8.30，TNG打麻将28”来一句话记多笔，或者问我“这个月花了多少”、“可以增加或删除某个分类吗？” 🐱")
        ]
    }

    /// 本地可直接回答的问题；答不了返回 nil（交给 Gemini 问账）。
    private func localAnswerBlocks(for trimmed: String, in store: MimiStore) -> [AIChatResponseBlock]? {
        // 1. Exact category table answer from IMG_2247 & IMG_2248
        if trimmed.contains("分类") && (trimmed.contains("增加") || trimmed.contains("删除") || trimmed.contains("标准") || trimmed.contains("哪些")) {
            let expenseRows: [(String, String)] = [
                ("餐饮", "做饭食材、餐厅、外卖外带、咖啡、饮品、零食甜品、酒吧酒水"),
                ("购物", "服饰鞋包、美妆护肤、数码电器、生活用品、个护服务、运费、二手租借"),
                ("交通", "公共交通、打车叫车、城际出行、加油充电、过路停车、养车、交通卡充值"),
                ("住房", "房租房贷、物业水电、话费网费、物业管理费、装修维修、家政服务"),
                ("休闲娱乐", "运动健身、线下娱乐、数字娱乐、旅游度假、收藏爱好、订阅会员"),
                ("医疗健康", "看病买药、医美齿科、保健养生、体检疫苗、康复陪护"),
                ("学习办公", "教育学费、职业培训、兴趣课程、图书文具"),
                ("宠物", "宠物食品、宠物用品、宠物医疗、宠物服务"),
                ("母婴", "婴儿食品、母婴用品、母婴服务"),
                ("资金往来", "还款、人情往来"),
                ("保险", "（无二级）"),
                ("投资理财", "（无二级）"),
                ("其他支出", "（无二级）")
            ]
            let incomeRows: [(String, String)] = [
                ("职业收入", "绩效奖金、津贴补助"),
                ("个体经营", "（无二级）"),
                ("副业兼职", "（无二级）"),
                ("投资收入", "股息分红、利息"),
                ("保险理赔", "（无二级）"),
                ("退款返还", "返现、报销、他人还款、退税"),
                ("礼金收入", "生活费"),
                ("其他收入", "二手买卖、好运收入")
            ]
            let incomeSectionHeader = "标准收入分类如下："
            let customNote = "\(incomeSectionHeader)\n另外你还自建了「家用」「车贷」两个支出分类和「别人转账」这个收入分类 😊\n你可以在左侧菜单 →「分类管理」中随时新增、编辑或长按排序分类。"
            return [
                .text("小金主，咪咪记账的标准支出分类如下："),
                .categoryTable(expenseRows: expenseRows, incomeRows: incomeRows, customNote: customNote)
            ]
        }

        // 2. Refund / Reimbursement / VIP / Shared Ledger answers
        if trimmed.contains("退款") {
            return [.text("小金主，记退款有两种方式：\n1. 点击原支出账单进入「账单详情」→ 在「添加退款/返现」中填入退款金额，系统会自动抵扣原支出；\n2. 直接记一笔「收入 → 退款返还」分类账单。")]
        }
        if trimmed.contains("报销") {
            return [.text("小金主，你可以在记账时打上「报销」标签，并在「资产管理 → 待报销」卡片中统一查看待报销总额（当前待报销 RM1,000.00）。收到报销款后记入「收入 → 退款返还-报销」即可。")]
        }
        if trimmed.contains("VIP") || trimmed.contains("会员") {
            return [.text("小金主，当前版本已为你永久解锁 Pro / VIP 全部高级权益（无限多账本、AI 智能助手、快捷指令自动截屏记账、分类预算与资产全维图表）🎉")]
        }
        if trimmed.contains("共享账本") || trimmed.contains("账本") {
            return [.text("你可以在首页左上角点击「☰」打开侧边菜单 → 选择「账本管理」创建新账本，或通过「导入导出」一键分享账本数据给家人伴侣。")]
        }

        // 3. Spending query (e.g. "这个月花了多少", "餐饮花了多少") — 按当前真实年月统计
        if trimmed.contains("多少") || trimmed.contains("统计") || trimmed.contains("分析") || trimmed.contains("复盘") {
            let now = Date()
            let cal = Calendar(identifier: .gregorian)
            let year = cal.component(.year, from: now)
            let month = cal.component(.month, from: now)
            let monthSpent = store.monthlyExpenseTotal(year: year, month: month)
            let monthIncome = store.monthlyIncomeTotal(year: year, month: month)
            let count = store.transactions.filter {
                $0.type == .expense && $0.includeInStats
                    && cal.component(.year, from: $0.date) == year
                    && cal.component(.month, from: $0.date) == month
            }.count
            return [
                .spendingSummary(
                    title: "\(year)年\(month)月 收支复盘",
                    amount: monthSpent,
                    count: count,
                    details: "本月共支出 RM\(String(format: "%.2f", monthSpent))（\(count)笔），总收入 RM\(String(format: "%.2f", monthIncome))，月预算剩余 RM\(String(format: "%.2f", max(0, store.currentLedger.monthlyBudget - monthSpent)))。"
                )
            ]
        }

        return nil
    }

    // MARK: - Chat History Persistence（本地文件，杀进程重开还在）

    private struct PersistedChatMessage: Codable {
        var isUser: Bool
        var text: String
        var drafts: [ParsedDraftBill]
        var createdAt: Date
    }

    private var historyFileURL: URL {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docDir.appendingPathComponent("mimi_ai_chat_history_v1.json")
    }

    public func clearHistory() {
        messages = []
        try? FileManager.default.removeItem(at: historyFileURL)
    }

    private func saveHistory() {
        let persisted: [PersistedChatMessage] = messages.suffix(100).map { message in
            var texts: [String] = []
            var drafts: [ParsedDraftBill] = []
            for block in message.blocks {
                switch block {
                case .text(let text):
                    texts.append(text)
                case .draftBills(let bills):
                    drafts.append(contentsOf: bills)
                case .categoryTable(let expenseRows, let incomeRows, let customNote):
                    var tableText = "标准支出分类如下："
                    for row in expenseRows {
                        tableText += "\n\(row.0)：\(row.1)"
                    }
                    if !incomeRows.isEmpty {
                        tableText += "\n标准收入分类如下："
                        for row in incomeRows {
                            tableText += "\n\(row.0)：\(row.1)"
                        }
                    }
                    if !customNote.isEmpty {
                        tableText += "\n\(customNote)"
                    }
                    texts.append(tableText)
                case .spendingSummary(let title, let amount, let count, let details):
                    texts.append("\(title)\n总支出 \(MimiTheme.formatRM(amount)) · 共 \(count) 笔\n\(details)")
                }
            }
            return PersistedChatMessage(
                isUser: message.isUser,
                text: message.isUser ? message.userText : texts.joined(separator: "\n"),
                drafts: drafts,
                createdAt: message.createdAt
            )
        }
        if let data = try? JSONEncoder().encode(persisted) {
            try? data.write(to: historyFileURL, options: .atomic)
        }
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyFileURL),
              let persisted = try? JSONDecoder().decode([PersistedChatMessage].self, from: data) else {
            return
        }
        messages = persisted.map { item in
            var blocks: [AIChatResponseBlock] = []
            if !item.text.isEmpty {
                blocks.append(.text(item.text))
            }
            if !item.drafts.isEmpty {
                blocks.append(.draftBills(item.drafts))
            }
            return AIChatMessageItem(
                isUser: item.isUser,
                userText: item.isUser ? item.text : "",
                blocks: blocks,
                createdAt: item.createdAt
            )
        }
    }

    // MARK: - Natural Language Parsing Helpers

    private func extractAmount(from clause: String) -> Double? {
        let pattern = #"(?:RM|MYR|¥|\$)?\s*([0-9]+(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsRange = NSRange(clause.startIndex..<clause.endIndex, in: clause)
        guard let match = regex.firstMatch(in: clause, range: nsRange),
              let valRange = Range(match.range(at: 1), in: clause) else { return nil }
        return Double(clause[valRange])
    }

    private func detectAccount(in clause: String) -> (String?, String) {
        let lower = clause.lowercased()
        if lower.contains("tng") || lower.contains("ewallet") || lower.contains("一触即通") {
            return ("acc_tng", "TNGewallet")
        }
        if lower.contains("pbb") || lower.contains("大众") {
            return ("acc_pbb", "PBBank")
        }
        if lower.contains("cimb") || lower.contains("联昌") {
            return ("acc_cimb", "CIMB")
        }
        if lower.contains("现金") || lower.contains("cash") {
            return ("acc_cash", "现金")
        }
        return ("acc_tng", "TNGewallet")
    }

    private func detectCategory(in clause: String, isIncome: Bool) -> (String, String?, String) {
        if isIncome {
            if clause.contains("还") || clause.contains("转账") {
                return ("inc_custom_transfer", nil, "别人转账")
            }
            return ("inc_salary", nil, "职业收入")
        }
        if clause.contains("加油") || clause.contains("打油") || clause.contains("充电") || clause.contains("shell") {
            return ("exp_transport", "exp_trans_fuel", "交通-加油充电")
        }
        if clause.contains("打车") || clause.contains("滴滴") || clause.contains("grab") {
            return ("exp_transport", "exp_trans_taxi", "交通-打车叫车")
        }
        if clause.contains("麻将") || clause.contains("电影") || clause.contains("游戏") || clause.contains("娱乐") {
            return ("exp_entertainment", "exp_ent_offline", "休闲娱乐-线下娱乐")
        }
        if clause.contains("奶茶") || clause.contains("饮品") || clause.contains("茶") || clause.contains("teh") {
            return ("exp_food", "exp_food_drink", "餐饮-饮品")
        }
        if clause.contains("咖啡") || clause.contains("coffee") {
            return ("exp_food", "exp_food_coffee", "餐饮-咖啡")
        }
        if clause.contains("甜品") || clause.contains("零食") || clause.contains("egg") {
            return ("exp_food", "exp_food_snack", "餐饮-零食甜品")
        }
        if clause.contains("外卖") {
            return ("exp_food", "exp_food_takeout", "餐饮-外卖外带")
        }
        if clause.contains("购物") || clause.contains("超市") || clause.contains("买") && !clause.contains("吃") {
            return ("exp_shopping", "exp_shop_daily", "购物-生活用品")
        }
        return ("exp_food", "exp_food_restaurant", "餐饮-餐厅")
    }

    private func detectRelativeDate(in clause: String, now: Date) -> Date {
        let cal = Calendar(identifier: .gregorian)
        if clause.contains("昨天") {
            return cal.date(byAdding: .day, value: -1, to: now) ?? now
        }
        if clause.contains("前天") {
            return cal.date(byAdding: .day, value: -2, to: now) ?? now
        }
        return now
    }

    private func cleanClauseNote(_ clause: String) -> String {
        clause
            .replacingOccurrences(of: #"(?:RM|MYR|¥|\$)?\s*[0-9]+(?:\.[0-9]{1,2})?(?:元|块|令吉)?"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
