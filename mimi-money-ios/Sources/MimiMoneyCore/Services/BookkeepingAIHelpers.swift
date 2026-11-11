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

public static func isSuspicious(amount: Double, sourceText: String? = nil) -> Bool {
guard amount > 0 else { return true}
if amount > maximumPlausibleAmount { return true}
guard let sourceText, amount == amount.rounded(), amount >= 1, amount <= 100 else {
return false
}
let intText = String(Int(amount))
if sourceText.contains(intText + "%") {
return true
}
// 状态栏被 OCR 读成 "$ 79" 这类样式、且正文没有真正的 RM 金额与之对应时，视为电量误读。
if sourceText.contains("$ " + intText) && !sourceText.contains("RM" + intText) {
return true
}
return false
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
lines.append("")
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
lines.append("")
for (name, total) in sorted {
lines.append("\(name)：\(formatRM(total))")
}
}

// 预算
let budgetTotal = store.monthlyBudgetTotal
let spent = store.monthlyExpenseTotal(year: year, month: month)
lines.append("本月总预算 \(formatRM(budgetTotal))，已支出 \(formatRM(spent))，剩余 \(formatRM(max(0, budgetTotal - spent)))。")
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
lines.append("" + parts.joined(separator: "；") + "；净资产 \(formatRM(store.netWorth))。")
}

// 相关记录明细（带上限）
let relevant = relevantTransactions(from: transactions, question: question, now: now)
if !relevant.isEmpty {
lines.append("")
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
