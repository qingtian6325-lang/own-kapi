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
}

@MainActor
public final class KapiAIEngine: ObservableObject {
    @Published public var messages: [AIChatMessageItem] = []
    @Published public var apiKey: String = UserDefaults.standard.string(forKey: "kapi_llm_api_key") ?? ""
    @Published public var apiBaseURL: String = UserDefaults.standard.string(forKey: "kapi_llm_base_url") ?? "https://api.deepseek.com/v1"
    @Published public var apiModel: String = UserDefaults.standard.string(forKey: "kapi_llm_model") ?? "deepseek-chat"

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

    public init() {}

    public func saveAPISettings(key: String, baseURL: String, model: String) {
        self.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(self.apiKey, forKey: "kapi_llm_api_key")
        UserDefaults.standard.set(self.apiBaseURL, forKey: "kapi_llm_base_url")
        UserDefaults.standard.set(self.apiModel, forKey: "kapi_llm_model")
    }

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

    @MainActor
    public func handleUserMessage(_ message: String, store: KapiStore) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(
            AIChatMessageItem(isUser: true, userText: trimmed, blocks: [.text(trimmed)])
        )
        let replyBlocks = buildReplyBlocks(for: trimmed, in: store)
        messages.append(
            AIChatMessageItem(isUser: false, userText: "", blocks: replyBlocks)
        )
    }

    public func handleUserMessage(_ message: String, in store: KapiStore) async -> [AIChatResponseBlock] {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return buildReplyBlocks(for: trimmed, in: store)
    }

    private func buildReplyBlocks(for trimmed: String, in store: KapiStore) -> [AIChatResponseBlock] {
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
                .text("小金主，咔皮记账的标准支出分类如下："),
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

        // 3. Spending query (e.g. "这个月花了多少", "餐饮花了多少")
        if trimmed.contains("多少") || trimmed.contains("统计") || trimmed.contains("分析") || trimmed.contains("复盘") {
            let monthSpent = store.monthlyExpenseTotal(year: 2026, month: 11)
            let monthIncome = store.monthlyIncomeTotal(year: 2026, month: 11)
            let count = store.transactions.filter { $0.type == .expense && $0.includeInStats }.count
            return [
                .spendingSummary(
                    title: "2026年11月 收支复盘",
                    amount: monthSpent,
                    count: count,
                    details: "本月共支出 RM\(String(format: "%.2f", monthSpent))（\(count)笔），总收入 RM\(String(format: "%.2f", monthIncome))，月预算剩余 RM\(String(format: "%.2f", max(0, store.currentLedger.monthlyBudget - monthSpent)))。"
                )
            ]
        }

        // 4. Multi-bill natural language bookkeeping
        let drafts = parseNaturalLanguageBills(trimmed)
        if !drafts.isEmpty {
            return [
                .text("小金主，咔皮已为你识别并拆分出 \(drafts.count) 笔账单，点击下方确认即可入账："),
                .draftBills(drafts)
            ]
        }

        return [
            .text("你可以直接对我说“今天午饭吃餐厅8.30，TNG打麻将28”来一句话记多笔，或者问我“这个月花了多少”、“可以增加或删除某个分类吗？” 🦫")
        ]
    }

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
