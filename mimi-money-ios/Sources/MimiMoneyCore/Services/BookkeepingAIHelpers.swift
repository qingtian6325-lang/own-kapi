import Foundation

// MARK: - 备注格式（本地兜底层）
//
// 规则（用户定）：向商家付款 → 「{商家名} 消费」；转账给个人 → 「转账给{姓名}」；
// 收到个人转账 → 「{姓名} 转账」。名字照截图原文原样。Gemini 给的备注干净时优先用它，
// 否则本地按规则生成，绝不把 OCR/Gemini 的杂讯带进账本。

public enum BillNoteFormatter {
public static func makeNote(
type: TransactionType,
counterparty: String,
counterpartyKind: String,
modelNote: String?
) -> String {
let name = counterparty.trimmingCharacters(in:.whitespacesAndNewlines)
if let modelNote, isCleanNote(modelNote) {
return modelNote.trimmingCharacters(in:.whitespacesAndNewlines)
}
if type == .transfer { return "账户转账" }
guard !name.isEmpty else { return ""}
let isPerson = counterpartyKind.lowercased() == "person"
switch type {
case .expense:
return isPerson ? "转账给\(name)" : "\(name) 消费"
case .income:
return isPerson ? "\(name) 转账" : "\(name) 收入"
case .transfer:
return "账户转账"
}
}

/// 干净备注：一句话、无换行、无链接/百分比杂讯、长度合理。
public static func isCleanNote(_ note: String) -> Bool {
let trimmed = note.trimmingCharacters(in:.whitespacesAndNewlines)
guard !trimmed.isEmpty, trimmed.count <= 30 else { return false}
if trimmed.contains("\n") || trimmed.contains("http") || trimmed.contains("%") {
return false
}
return true
}
}

// MARK: - 金额合理性拦截
//
// 明显误读的金额只进未确认/待确认口径，不走正常入账呈现：
// - 金额 <= 0
// - 金额大得离谱（> RM100,000：本 App 是个人日常记账，单笔付款截图超过十万必是误读）
// - 金额与状态栏电量百分比同值（如把状态栏 "79%" / "$ 79" 当成金额）

public enum BillAmountSanity {
public static let maximumPlausibleAmount: Double = 100_000

public static func isSuspicious(
amount: Double,
sourceText: String? = nil,
draftNote: String? = nil
) -> Bool {
guard amount > 0 else { return true}
if amount > maximumPlausibleAmount { return true}
let intCandidate = amount == amount.rounded() && amount >= 1 && amount <= 100
guard intCandidate else { return false}
let intText = String(Int(amount))
if let sourceText {
if sourceText.contains(intText + "%") {
return true
}
// 状态栏被 OCR 读成 "$ 79" 这类样式、且正文没有真正的 RM 金额与之对应时，视为电量误读。
if sourceText.contains("$ " + intText) && !sourceText.contains("RM" + intText) {
return true
}
}
// 仅当调用方显式传入 draftNote（Gemini 草稿路径）时：
// 电量区间整数 + 空/纯数字备注 → 高度可疑。未传 draftNote 时不启用，避免误伤旧口径。
if let draftNote {
let note = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
if note.isEmpty { return true}
if note.allSatisfy({ $0.isNumber || $0.isWhitespace }) { return true}
}
return false
}

public static func isSuspicious(draft: ParsedDraftBill) -> Bool {
isSuspicious(amount: draft.amount, sourceText: draft.merchantOrNote, draftNote: draft.merchantOrNote)
}
}

// MARK: - 本地可离线回答的问账（分类表 / VIP / 整月泛问汇总）
//
// 细分类问题（如「餐饮花了多少」）故意返回 nil，交给 Gemini 带账目上下文回答，
// 避免本地整月汇总「抢答」把分类问句答成整月。

public enum LocalBookkeepingAnswerer {
@MainActor
public static func blocks(for trimmed: String, in store: MimiStore) -> [AIChatResponseBlock]? {
if trimmed.contains("分类") && (trimmed.contains("增加") || trimmed.contains("删除") || trimmed.contains("标准") || trimmed.contains("哪些")) {
let expenseRows: [(String, String)] = DefaultCatalog.standardExpenseCategories().map { group in
let subs = group.subCategories.map(\.name).joined(separator: "、")
return (group.name, subs.isEmpty ? "（无二级）" : subs)
}
let incomeRows: [(String, String)] = DefaultCatalog.standardIncomeCategories().map { group in
let subs = group.subCategories.map(\.name).joined(separator: "、")
return (group.name, subs.isEmpty ? "（无二级）" : subs)
}
let customNote = "标准收入分类如下：\n另外你还自建了「家用」「车贷」两个支出分类和「别人转账」这个收入分类 😊\n你可以在左侧菜单 →「分类管理」中随时新增、编辑分类；点右上角 ⋯ 进入排序模式用上下箭头调整顺序。"
return [
.text("小金主，咪咪记账的标准支出分类如下："),
.categoryTable(expenseRows: expenseRows, incomeRows: incomeRows, customNote: customNote)
]
}

if trimmed.contains("退款") {
return [.text("小金主，记退款有两种方式：\n1. 点击原支出账单进入「账单详情」→ 在「添加退款/返现」中填入退款金额，系统会自动抵扣原支出；\n2. 直接记一笔「收入 → 退款返还」分类账单。")]
}
if trimmed.contains("报销") {
return [.text("小金主，你可以在记账时打上「报销」标签，并在「资产管理 → 待报销」卡片中统一查看待报销总额。收到报销款后记入「收入 → 退款返还-报销」即可。")]
}
if trimmed.contains("VIP") || trimmed.contains("会员") {
return [.text("小金主，当前版本已为你永久解锁 Pro / VIP 全部高级权益（无限多账本、AI 智能助手、快捷指令自动截屏记账、分类预算与资产全维图表）🎉")]
}
if trimmed.contains("共享账本") || trimmed.contains("账本") {
return [.text("你可以在首页左上角点击「☰」打开侧边菜单 → 选择「账本管理」创建新账本，或通过「导入导出」一键分享账本数据给家人伴侣。")]
}

if trimmed.contains("多少") || trimmed.contains("统计") || trimmed.contains("分析") || trimmed.contains("复盘") {
// 问句里点名了具体分类 → 交给 Gemini，不返回整月汇总
let categoryNames = (DefaultCatalog.standardExpenseCategories() + DefaultCatalog.standardIncomeCategories()).map(\.name)
if categoryNames.contains(where: { trimmed.contains($0) }) {
return nil
}
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
}

// MARK: - 记账句 / 问账句判别（纯函数）
//
// 拿不准一律按问账处理；只有「无任何疑问标记 + 能解析出至少一笔带金额的草稿」才判为记账句。

public enum BillMessageKind: Equatable, Sendable {
case billDraft
case question
}

public enum BillMessageClassifier {
public static let questionMarkers: [String] = [
"?", "？", "吗", "什么", "多少", "哪", "怎么", "如何",
"查询", "查找", "超过", "最高", "最低", "最近",
"统计", "分析", "为什么", "能不能", "可不可以", "剩多少", "花了多少"
]

public static func classify(_ message: String, draftCount: Int) -> BillMessageKind {
let trimmed = message.trimmingCharacters(in:.whitespacesAndNewlines)
guard !trimmed.isEmpty else { return .question }
if questionMarkers.contains(where: { trimmed.contains($0)}) {
return .question
}
return draftCount > 0 ? .billDraft : .question
}
}

// MARK: - 账目上下文构建（问账用，本地生成，带上限）

public enum LedgerContextBuilder {
/// 相关记录明细上限：最多 30 条。
public static let maxRecentRecords = 30
/// 上下文总字符上限：约 6000 字，超出截断明细部分。
public static let maxCharacters = 6000

@MainActor
public static func buildContext(store: MimiStore, question: String, now: Date = Date()) -> String {
let cal = Calendar(identifier:.gregorian)
let year = cal.component(.year, from: now)
let month = cal.component(.month, from: now)
let transactions = store.transactions

var lines: [String] = []
let dateFormatter = DateFormatter()
dateFormatter.locale = Locale(identifier: "zh_CN")
dateFormatter.dateFormat = "yyyy年M月d日"
lines.append("今天是 \(dateFormatter.string(from: now))。")

// 近 6 个月月度汇总
lines.append("【月度收支汇总（近6个月）】")
for line in monthlySummaryLines(transactions: transactions, monthsBack: 6, now: now) {
lines.append(line)
}

// 本月分类支出汇总
let monthExpenses = transactions.filter {
$0.type == .expense && $0.includeInStats
&& cal.component(.year, from: $0.date) == year
&& cal.component(.month, from: $0.date) == month
}
if !monthExpenses.isEmpty {
var byCategory: [String: Double] = [:]
for tx in monthExpenses {
let primary = tx.categoryPath.components(separatedBy: "-").first ?? tx.categoryPath
byCategory[primary, default: 0] += tx.amount
}
let sorted = byCategory.sorted { $0.value > $1.value}
lines.append("【本月分类支出】")
for (name, total) in sorted {
lines.append("\(name)：\(formatRM(total))")
}
}

// 预算
let budgetTotal = store.monthlyBudgetTotal
let spent = store.monthlyExpenseTotal(year: year, month: month)
lines.append("【预算】本月总预算 \(formatRM(budgetTotal))，已支出 \(formatRM(spent))，剩余 \(formatRM(max(0, budgetTotal - spent)))。")
if !store.categoryBudgets.isEmpty {
let parts = store.categoryBudgets.map { item in
let used = store.categorySpent(for: item.categoryName, year: year, month: month)
return "\(item.categoryName) 剩 \(formatRM(max(0, item.monthlyLimit - used)))/\(formatRM(item.monthlyLimit))"
}
lines.append("分类预算剩余：" + parts.joined(separator: "；"))
}

// 账户余额
if !store.accounts.isEmpty {
let parts = store.accounts.map { "\($0.name) \(formatRM($0.balance))"}
lines.append("【账户余额】" + parts.joined(separator: "；") + "；净资产 \(formatRM(store.netWorth))。")
}

// 相关记录明细（带上限）
let relevant = relevantTransactions(from: transactions, question: question, now: now)
if !relevant.isEmpty {
lines.append("【相关账单明细（最近\(relevant.count)笔）】")
let itemFormatter = DateFormatter()
itemFormatter.locale = Locale(identifier: "en_US_POSIX")
itemFormatter.dateFormat = "yyyy-MM-dd"
for tx in relevant {
let sign = tx.type == .income ? "+" : "-"
lines.append("\(itemFormatter.string(from: tx.date)) \(tx.categoryPath) \(sign)\(formatRM(tx.amount)) 账户:\(tx.accountName) 备注:\(tx.note)")
}
}

var context = lines.joined(separator: "\n")
if context.count > maxCharacters {
context = String(context.prefix(maxCharacters)) + "\n（数据已按上限截断）"
}
return context
}

/// 纯函数：按月汇总收支，供上下文与单测共用。
public static func monthlySummaryLines(transactions: [TransactionItem], monthsBack: Int, now: Date) -> [String] {
let cal = Calendar(identifier:.gregorian)
var lines: [String] = []
for offset in 0..<monthsBack {
guard let monthDate = cal.date(byAdding:.month, value: -offset, to: now) else { continue}
let y = cal.component(.year, from: monthDate)
let m = cal.component(.month, from: monthDate)
let inMonth = transactions.filter {
cal.component(.year, from: $0.date) == y && cal.component(.month, from: $0.date) == m
}
guard !inMonth.isEmpty else { continue}
let expense = inMonth.filter { $0.type == .expense && $0.includeInStats}.reduce(0) { $0 + $1.amount}
let income = inMonth.filter { $0.type == .income && $0.includeInStats}.reduce(0) { $0 + $1.amount}
let count = inMonth.filter { $0.includeInStats}.count
lines.append("\(y)年\(m)月：支出 \(formatRM(expense))，收入 \(formatRM(income))，共 \(count) 笔")
}
return lines
}

/// 挑选与问题相关的记录：问题里有分类/商家关键词就优先匹配，其次按时间倒序补足，上限 maxRecentRecords。
public static func relevantTransactions(from transactions: [TransactionItem], question: String, now: Date) -> [TransactionItem] {
let sorted = transactions
.filter { $0.includeInStats}
.sorted { $0.date > $1.date}
let keywords = DefaultCatalog.standardExpenseCategories().map(\.name)
+ DefaultCatalog.standardIncomeCategories().map(\.name)
let matchedKeywords = keywords.filter { question.contains($0)}
var picked: [TransactionItem] = []
if !matchedKeywords.isEmpty {
picked = sorted.filter { tx in
matchedKeywords.contains(where: { tx.categoryPath.contains($0) || tx.note.contains($0)})
}
}
if picked.count < maxRecentRecords {
for tx in sorted where !picked.contains(where: { $0.id == tx.id}) {
picked.append(tx)
if picked.count >= maxRecentRecords { break}
}
}
return Array(picked.prefix(maxRecentRecords))
}

private static func formatRM(_ value: Double) -> String {
"RM" + String(format: "%.2f", value)
}
}
