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
    /// 问账等待态：回复到达前显示「咪咪思考中…」，回复/报错后被整块替换。
    case pendingAnswer
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
        case (.pendingAnswer, .pendingAnswer):
            return true
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

    // 旧版自定义大模型设置（v1.2.0 起识别/问账统一走 Gemini；Key 不再写 UserDefaults）
    @Published public var apiKey: String = ""
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

    /// 金标 AI 记账空状态建议气泡（点即发送）
    public static let exampleQuestions: [String] = [
        "查询本月单笔消费超过200块的账单",
        "查看我最近3天的消费记录？",
        "我最近一次购物买了什么？"
    ]

    public init() {
        clearLegacyPlaintextAPIKeyIfNeeded()
        loadHistory()
    }

    /// 清除 v1.2.0 之前可能残留在 UserDefaults 的明文 LLM Key。
    public func clearLegacyPlaintextAPIKeyIfNeeded() {
        if UserDefaults.standard.object(forKey: "mimi_llm_api_key") != nil {
            UserDefaults.standard.removeObject(forKey: "mimi_llm_api_key")
        }
    }

    public func saveAPISettings(key: String, baseURL: String, model: String) {
        // Key 故意不落盘：旧自定义 LLM 通道已废弃，避免再把密钥写进 UserDefaults。
        self.apiKey = ""
        self.apiBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.removeObject(forKey: "mimi_llm_api_key")
        UserDefaults.standard.set(self.apiBaseURL, forKey: "mimi_llm_base_url")
        UserDefaults.standard.set(self.apiModel, forKey: "mimi_llm_model")
        _ = key
    }

    // MARK: - Natural Language Bill Parsing

    /// Splits a single natural-language input into one or more `ParsedDraftBill` items ("一句话记多笔").
    /// Supports both punctuation delimiters ("，,；;\n") and whitespace between an amount and the next keyword (e.g. "午饭 24.5 咖啡 12.9 打车 18").
    public func parseNaturalLanguageBills(
        _ input: String,
        now: Date = Date(),
        preferredAccountId: String? = nil,
        preferredAccountName: String? = nil
    ) -> [ParsedDraftBill] {
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
            let (accountId, accountName) = detectAccount(
                in: clause,
                preferredAccountId: preferredAccountId,
                preferredAccountName: preferredAccountName
            )
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

    /// 从账本里取最近一笔有账户的交易，作为自然语言记账默认账户。
    public static func preferredAccount(from store: MimiStore) -> (id: String, name: String)? {
        guard let tx = store.transactions.first(where: { $0.accountId != nil || !$0.accountName.isEmpty }) else {
            return nil
        }
        // resolveAccountId 返回 String?；必须解包成非可选，否则 macOS host 编译报
        // cannot convert '(String?, String)' to '(id: String, name: String)'
        guard let id = tx.accountId ?? DefaultCatalog.resolveAccountId(from: tx.accountName) else {
            return nil
        }
        let name = DefaultCatalog.resolveAccountName(from: id)
        return (id: id, name: name)
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

        let preferred = Self.preferredAccount(from: store)
        let drafts = parseNaturalLanguageBills(
            trimmed,
            preferredAccountId: preferred?.id,
            preferredAccountName: preferred?.name
        )
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

        if let local = LocalBookkeepingAnswerer.blocks(for: trimmed, in: store) {
            messages.append(AIChatMessageItem(isUser: false, userText: "", blocks: local))
            saveHistory()
            return
        }

        guard AIEngineSettings.hasAPIKey else {
            let provider = AIEngineSettings.provider
            messages.append(
                AIChatMessageItem(isUser: false, userText: "", blocks: [
                    .text("小金主，这个问题要联网查账才能答：请先到「设置 → AI 识别引擎」填入你的 \(provider.displayName) API Key（\(provider.keyApplyHint)），填好后就能问我「本月单笔超过 200 的账单」「本周最贵的一笔」这类问题了 🐱")
                ])
            )
            saveHistory()
            return
        }

        let placeholder = AIChatMessageItem(isUser: false, userText: "", blocks: [.pendingAnswer])
        messages.append(placeholder)
        saveHistory()
        let placeholderId = placeholder.id
        let providerName = AIEngineSettings.provider.displayName
        Task { [weak self] in
            guard let self else { return }
            do {
                let answer: String
                switch AIEngineSettings.provider {
                case .groq:
                    answer = try await GroqClient.answerQuestion(trimmed, store: store)
                case .gemini:
                    answer = try await GeminiClient.answerQuestion(trimmed, store: store)
                }
                AIEngineSettings.recordCallStatus(success: true, message: "问账成功（\(providerName)）")
                self.replaceMessageBlocks(id: placeholderId, blocks: [.text(answer)])
            } catch {
                let reason = (error as? GeminiError)?.description ?? error.localizedDescription
                AIEngineSettings.recordCallStatus(success: false, message: "问账失败：\(reason)")
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
    public func appendRecognizedDraft(
        _ draft: ParsedDraftBill,
        sourceLabel: String,
        isSuspiciousAmount: Bool = false
    ) {
        let preface: String
        if isSuspiciousAmount {
            preface = "小金主，已从\(sourceLabel)识别出账单，但金额看起来不太对劲（可能是误读）。请仔细核对后再点「确认记账」；没把握就先取消，改用一句话记账："
        } else {
            preface = "小金主，已从\(sourceLabel)识别出这笔账单草稿，核对无误后点「确认记账」才会入账："
        }
        messages.append(
            AIChatMessageItem(isUser: false, userText: "", blocks: [
                .text(preface),
                .draftBills([draft])
            ])
        )
        saveHistory()
    }

    /// 相册/拍照识别失败时如实告知：不生成草稿、不落账，并给出可行的下一步。
    public func appendRecognitionFailure(_ dialogText: String, sourceLabel: String) {
        messages.append(
            AIChatMessageItem(isUser: false, userText: "", blocks: [
                .text("小金主，\(sourceLabel)这张图没识别成。\(dialogText) 你可以换一张更清楚的截图再发，或直接用一句话把这笔账告诉我（例如：午餐 38）。")
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
        if let local = LocalBookkeepingAnswerer.blocks(for: trimmed, in: store) {
            return local
        }
        let preferred = Self.preferredAccount(from: store)
        let drafts = parseNaturalLanguageBills(
            trimmed,
            preferredAccountId: preferred?.id,
            preferredAccountName: preferred?.name
        )
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
                case .pendingAnswer:
                    // 等待态不按原样持久化：若 App 在等待中被杀，重开后显示未完成提示而非永久转圈
                    texts.append("（上次问账没有完成，请重新问一次）")
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

    private func detectAccount(
        in clause: String,
        preferredAccountId: String? = nil,
        preferredAccountName: String? = nil
    ) -> (String?, String) {
        let lower = clause.lowercased()
        if lower.contains("tng") || lower.contains("ewallet") || lower.contains("一触即通") {
            return ("acc_tng", "TNGewallet")
        }
        if lower.contains("pbb") || lower.contains("大众") || lower.contains("pbbank") {
            return ("acc_pbb", "PBBank")
        }
        if lower.contains("cimb") || lower.contains("联昌") {
            return ("acc_cimb", "CIMB")
        }
        if lower.contains("现金") || lower.contains("cash") {
            return ("acc_cash", "现金")
        }
        if let preferredAccountId, let preferredAccountName {
            return (preferredAccountId, preferredAccountName)
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
