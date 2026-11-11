import Foundation
#if canImport(Security)
import Security
#endif

// MARK: - Keychain Helper (API keys live ONLY here — never UserDefaults / repo / logs)

public enum KeychainHelper {
private static let service = "com.jinghao.mimimoney.gemini"
private static let account = "gemini_api_key"

public static func saveGeminiAPIKey(_ key: String?) {
#if canImport(Security)
let trimmed = key?.trimmingCharacters(in:.whitespacesAndNewlines)?? ""
let query: [String: Any] = [
kSecClass as String: kSecClassGenericPassword,
kSecAttrService as String: service,
kSecAttrAccount as String: account
]
SecItemDelete(query as CFDictionary)
guard!trimmed.isEmpty, let data = trimmed.data(using:.utf8) else { return}
var attributes = query
attributes[kSecValueData as String] = data
attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
SecItemAdd(attributes as CFDictionary, nil)
#endif
}

public static func readGeminiAPIKey() -> String? {
#if canImport(Security)
let query: [String: Any] = [
kSecClass as String: kSecClassGenericPassword,
kSecAttrService as String: service,
kSecAttrAccount as String: account,
kSecReturnData as String: true,
kSecMatchLimit as String: kSecMatchLimitOne
]
var item: CFTypeRef?
let status = SecItemCopyMatching(query as CFDictionary, &item)
guard status == errSecSuccess, let data = item as? Data,
let value = String(data: data, encoding:.utf8),
!value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {
return nil
}
return value.trimmingCharacters(in:.whitespacesAndNewlines)
#else
return nil
#endif
}
}

// MARK: - Gemini Settings

public enum GeminiSettings {
/// 出厂默认模型：Google 官方 Gemini API 定价页（ai.google.dev/gemini-api/docs/pricing，
/// 2026-11-11 核实）中 Free Tier 列为 "Free of charge" 的现行旗舰 Flash 模型。
public static let defaultModelName = "gemini-3.8-flash"

private static let modelUserDefaultsKey = "mimi_gemini_model_name"
private static let statusUserDefaultsKey = "mimi_gemini_last_call_status"
private static let statusDateUserDefaultsKey = "mimi_gemini_last_call_status_date"

public static var modelName: String {
get {
let saved = UserDefaults.standard.string(forKey: modelUserDefaultsKey)?
.trimmingCharacters(in:.whitespacesAndNewlines)
return (saved?.isEmpty == false)? saved!: defaultModelName
}
set {
let trimmed = newValue.trimmingCharacters(in:.whitespacesAndNewlines)
UserDefaults.standard.set(trimmed.isEmpty? defaultModelName: trimmed, forKey: modelUserDefaultsKey)
}
}

public static var apiKey: String? {
KeychainHelper.readGeminiAPIKey()
}

public static var hasAPIKey: Bool {
apiKey!= nil
}

public static func saveAPIKey(_ key: String?) {
KeychainHelper.saveGeminiAPIKey(key)
}

/// 最近一次 Gemini 调用状态（只记成功/失败与原因简述，绝不记录 key）。
public static func recordCallStatus(success: Bool, message: String) {
let prefix = success? "成功": "失败"
UserDefaults.standard.set("\(prefix)：\(message)", forKey: statusUserDefaultsKey)
UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: statusDateUserDefaultsKey)
}

public static var lastCallStatusText: String? {
guard let text = UserDefaults.standard.string(forKey: statusUserDefaultsKey) else { return nil}
let ts = UserDefaults.standard.double(forKey: statusDateUserDefaultsKey)
guard ts > 0 else { return text}
let formatter = DateFormatter()
formatter.locale = Locale(identifier: "zh_CN")
formatter.dateFormat = "MM-dd HH:mm"
return "\(text)（\(formatter.string(from: Date(timeIntervalSince1970: ts)))）"
}
}

// MARK: - Gemini Errors

public enum GeminiError: Error, CustomStringConvertible {
case missingAPIKey
case httpStatus(Int, String)
case emptyResponse
case decodingFailed(String)
case transport(String)

public var description: String {
switch self {
case.missingAPIKey:
return "尚未填写 Gemini API Key"
case.httpStatus(let code, let message):
if code == 429 {
return "HTTP 429：免费额度已用完或请求过于频繁"
}
if code == 400 || code == 403 {
return "HTTP \(code)：API Key 无效或请求被拒绝（\(message)）"
}
return "HTTP \(code)：\(message)"
case.emptyResponse:
return "Gemini 返回为空"
case.decodingFailed(let detail):
return "Gemini 返回内容无法解析（\(detail)）"
case.transport(let detail):
return "网络请求失败（\(detail)）"
}
}
}

// MARK: - Gemini Bill DTO (structured output)

public struct GeminiBillDTO: Codable, Equatable, Sendable {
public var type: String // expense | income | transfer
public var amount: Double
public var counterparty: String // 商家名或对方姓名，照截图原文
public var counterpartyKind: String // merchant | person
public var account: String // 付款/收款账户名（App 现有账户之一）
public var targetAccount: String? // 仅转账时：对方账户
public var primaryCategory: String // 一级分类名（App 现有分类）
public var subCategory: String // 二级分类名，可为空字符串
public var occurredAt: String // "yyyy-MM-dd HH:mm"
public var note: String // 备注（按规则生成）

public init(
type: String,
amount: Double,
counterparty: String,
counterpartyKind: String,
account: String,
targetAccount: String? = nil,
primaryCategory: String,
subCategory: String,
occurredAt: String,
note: String
) {
self.type = type
self.amount = amount
self.counterparty = counterparty
self.counterpartyKind = counterpartyKind
self.account = account
self.targetAccount = targetAccount
self.primaryCategory = primaryCategory
self.subCategory = subCategory
self.occurredAt = occurredAt
self.note = note
}

/// 把 Gemini 的结构化结果换算成 App 统一的账单草稿。
/// 分类名再经 DefaultCatalog 按 id 解析校验；备注经 BillNoteFormatter 本地兜底。
public func toDraftBill(now: Date = Date()) -> ParsedDraftBill {
let txType: TransactionType
switch type.lowercased() {
case "income": txType =.income
case "transfer": txType =.transfer
default: txType =.expense
}

let categoryPath: String
let primaryId: String
let subId: String?
let categoryDisplay: String
if txType ==.transfer {
categoryPath = "转账"
primaryId = "transfer"
subId = nil
categoryDisplay = "转账"
} else {
let path = subCategory.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
? primaryCategory
: "\(primaryCategory)-\(subCategory)"
let resolved = DefaultCatalog.resolveCategoryIds(from: path, type: txType)
primaryId = resolved.primaryId
subId = resolved.subId
let display = DefaultCatalog.resolveCategoryDisplay(primaryId: primaryId, subId: subId, type: txType)
categoryPath = display.categoryPath
categoryDisplay = display.categoryPath
}

let accountId = DefaultCatalog.resolveAccountId(from: account)
let accountName = DefaultCatalog.resolveAccountName(from: accountId)
let note = BillNoteFormatter.makeNote(
type: txType,
counterparty: counterparty,
counterpartyKind: counterpartyKind,
modelNote: note
)

return ParsedDraftBill(
type: txType,
amount: amount,
currency:.myr,
primaryCategoryId: primaryId,
subCategoryId: subId,
categoryDisplayName: categoryDisplay,
accountId: accountId,
accountDisplayName: accountName,
merchantOrNote: note.isEmpty? counterparty: note,
occurredAt: GeminiBillDTO.parseOccurredAt(occurredAt)?? now
)
}

public static func parseOccurredAt(_ text: String) -> Date? {
let trimmed = text.trimmingCharacters(in:.whitespacesAndNewlines)
guard!trimmed.isEmpty else { return nil}
let formatter = DateFormatter()
formatter.locale = Locale(identifier: "en_US_POSIX")
formatter.timeZone = TimeZone.current
for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy/MM/dd HH:mm", "dd/MM/yyyy HH:mm", "dd/MM/yyyy HH:mm:ss"] {
formatter.dateFormat = format
if let date = formatter.date(from: trimmed) {
return date
}
}
return nil
}
}

// MARK: - Gemini REST Client

public enum GeminiClient {
public static let recognitionTimeoutSeconds: TimeInterval = 8

private static func endpoint(model: String, action: String) -> URL? {
let encoded = model.addingPercentEncoding(withAllowedCharacters:.urlPathAllowed)?? model
return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encoded):\(action)")
}

private static func performRequest(
model: String,
body: [String: Any],
timeout: TimeInterval
) async throws -> [String: Any] {
guard let apiKey = GeminiSettings.apiKey else {
throw GeminiError.missingAPIKey
}
guard let url = endpoint(model: model, action: "generateContent") else {
throw GeminiError.transport("模型名无效")
}
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.timeoutInterval = timeout
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
request.httpBody = try JSONSerialization.data(withJSONObject: body)

let data: Data
let response: URLResponse
do {
(data, response) = try await URLSession.shared.data(for: request)
} catch {
throw GeminiError.transport(error.localizedDescription)
}
if let http = response as? HTTPURLResponse,!(200...299).contains(http.statusCode) {
let message = extractErrorMessage(from: data)
throw GeminiError.httpStatus(http.statusCode, message)
}
guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
throw GeminiError.decodingFailed("响应不是 JSON")
}
return json
}

private static func extractErrorMessage(from data: Data) -> String {
guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
let error = json["error"] as? [String: Any],
let message = error["message"] as? String else {
return "无详细信息"
}
return String(message.prefix(120))
}

private static func extractText(from responseJSON: [String: Any]) throws -> String {
guard let candidates = responseJSON["candidates"] as? [[String: Any]],
let content = candidates.first?["content"] as? [String: Any],
let parts = content["parts"] as? [[String: Any]] else {
throw GeminiError.emptyResponse
}
let text = parts.compactMap { $0["text"] as? String}.joined()
guard!text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {
throw GeminiError.emptyResponse
}
return text
}

// MARK: 测试连接（查模型详情，最小成本验证 key 与模型名）

public static func testConnection() async -> (success: Bool, message: String) {
guard let apiKey = GeminiSettings.apiKey else {
return (false, "尚未填写 Gemini API Key")
}
let model = GeminiSettings.modelName
let encoded = model.addingPercentEncoding(withAllowedCharacters:.urlPathAllowed)?? model
guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encoded)") else {
return (false, "模型名无效")
}
var request = URLRequest(url: url)
request.httpMethod = "GET"
request.timeoutInterval = 10
request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
do {
let (data, response) = try await URLSession.shared.data(for: request)
if let http = response as? HTTPURLResponse {
if (200...299).contains(http.statusCode) {
GeminiSettings.recordCallStatus(success: true, message: "测试连接成功（\(model)）")
return (true, "连接成功，模型 \(model) 可用")
}
let message = extractErrorMessage(from: data)
GeminiSettings.recordCallStatus(success: false, message: "测试连接 HTTP \(http.statusCode)")
return (false, GeminiError.httpStatus(http.statusCode, message).description)
}
return (false, "无 HTTP 响应")
} catch {
GeminiSettings.recordCallStatus(success: false, message: "测试连接网络失败")
return (false, "网络请求失败（\(error.localizedDescription)）")
}
}

// MARK: 截图识别（结构化 JSON 输出）

public static func recognizeBill(imageData: Data, now: Date = Date()) async throws -> ParsedDraftBill {
let model = GeminiSettings.modelName
let mimeType = imageData.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47])? "image/png": "image/jpeg"

let body: [String: Any] = [
"systemInstruction": ["parts": [["text": recognitionSystemPrompt(now: now)]]],
"contents": [[
"role": "user",
"parts": [
["inline_data": ["mime_type": mimeType, "data": imageData.base64EncodedString()]],
["text": "请识别这张付款/收款/转账截图，按系统规则输出 JSON。"]
]
]],
"generationConfig": [
"temperature": 0.1,
"responseMimeType": "application/json",
"responseSchema": recognitionResponseSchema()
]
]

let json = try await performRequest(model: model, body: body, timeout: recognitionTimeoutSeconds)
let text = try extractText(from: json)
guard let data = text.data(using:.utf8) else {
throw GeminiError.decodingFailed("文本编码失败")
}
let dto: GeminiBillDTO
do {
dto = try JSONDecoder().decode(GeminiBillDTO.self, from: data)
} catch {
throw GeminiError.decodingFailed(error.localizedDescription)
}
return dto.toDraftBill(now: now)
}

public static func recognitionSystemPrompt(now: Date = Date()) -> String {
let formatter = DateFormatter()
formatter.locale = Locale(identifier: "zh_CN")
formatter.dateFormat = "yyyy-MM-dd HH:mm"
let todayText = formatter.string(from: now)

let expenseGroups = DefaultCatalog.standardExpenseCategories()
let incomeGroups = DefaultCatalog.standardIncomeCategories()
let expenseLines = expenseGroups.map { group in
let subs = group.subCategories.map(\.name).joined(separator: "、")
return subs.isEmpty? group.name: "\(group.name)：\(subs)"
}.joined(separator: "\n")
let incomeLines = incomeGroups.map { group in
let subs = group.subCategories.map(\.name).joined(separator: "、")
return subs.isEmpty? group.name: "\(group.name)：\(subs)"
}.joined(separator: "\n")
let accountNames = DefaultCatalog.defaultAccounts().map(\.name).joined(separator: "、")

return """
你是「咪咪记账」的账单识别引擎，只输出符合 schema 的 JSON，不要输出任何其他文字。

现在时间是 \(todayText)（马来西亚时间）。截图上的日期一律是马来西亚格式「日/月/年」：例如 08/11/2026 表示 2026 年 11 月 8 日，绝不能读成 8 月 11 日。时间是 24 小时制。截图上没有日期时用现在时间。

判断顺序：
1. 先判断收支类型 type：付款/消费/扣款成功 = expense；收款/到账/工资/退款 = income；只有当截图明确显示是本人两个账户之间的转账（两边账户都属于下方账户列表）时才用 transfer。把钱转给另一个人（DuitNow 给个人等）属于 expense，不是 transfer。
2. 金额 amount 取交易本身的金额（通常带 RM 标志的主金额），不要取账户余额、参考编号、订单号，也不要取手机状态栏的时间或电量百分比数字。
3. counterparty 照截图原文原样填写（英文大写就保持大写）：商家付款填商家名，个人转账填对方姓名。counterpartyKind：商家/公司填 merchant，个人填 person。
4. account 必须从账户列表中选最接近的一个：\(accountNames)。TNG eWallet / Touch 'n Go 选 TNGewallet；Public Bank 选 PBBank。
5. 分类必须按商家/业务性质判断，只能从下面的分类表里选一级与二级，不要靠单个关键词硬猜：
支出分类：
\(expenseLines)
收入分类：
\(incomeLines)
判断示例：餐厅、餐馆、食堂、快餐店 → 餐饮-餐厅；咖啡店 → 餐饮-咖啡；奶茶/饮料店 → 餐饮-饮品；油站（Petronas、Shell、Caltex 等）加油 → 交通-加油充电；Grab/打车 → 交通-打车叫车；超市买日用品 → 购物-生活用品；话费/宽带充值 → 住房-话费网费；房租 → 住房-房租房贷；转钱给朋友/家人 → 资金往来-人情往来（到期还款则选 资金往来-还款）；收到别人转账 → 收入分类「别人转账」（无二级，subCategory 留空）。
6. 备注 note 按规则生成，简洁一句、不带杂讯：向商家付款 → 「{商家名} 消费」；把钱转给个人 → 「转账给{姓名}」；收到个人转账 → 「{姓名} 转账」；本人账户间转账 → 「账户转账」。名字照截图原文。
7. occurredAt 输出 "yyyy-MM-dd HH:mm" 格式。
"""
}

public static func recognitionResponseSchema() -> [String: Any] {
let expenseNames = DefaultCatalog.standardExpenseCategories().map(\.name)
let incomeNames = DefaultCatalog.standardIncomeCategories().map(\.name)
let allPrimary = expenseNames + incomeNames
let allSubs = (DefaultCatalog.standardExpenseCategories() + DefaultCatalog.standardIncomeCategories())
.flatMap { $0.subCategories.map(\.name)}
let accountNames = DefaultCatalog.defaultAccounts().map(\.name)
return [
"type": "OBJECT",
"properties": [
"type": ["type": "STRING", "enum": ["expense", "income", "transfer"]],
"amount": ["type": "NUMBER"],
"counterparty": ["type": "STRING"],
"counterpartyKind": ["type": "STRING", "enum": ["merchant", "person"]],
"account": ["type": "STRING", "enum": accountNames],
"targetAccount": ["type": "STRING", "enum": accountNames + [""]],
"primaryCategory": ["type": "STRING", "enum": allPrimary],
"subCategory": ["type": "STRING", "enum": allSubs + [""]],
"occurredAt": ["type": "STRING"],
"note": ["type": "STRING"]
],
"required": ["type", "amount", "counterparty", "counterpartyKind", "account", "primaryCategory", "subCategory", "occurredAt", "note"]
]
}

// MARK: 问账（问题 + 本地账目上下文）

@MainActor
public static func answerQuestion(_ question: String, store: MimiStore, now: Date = Date()) async throws -> String {
let model = GeminiSettings.modelName
let context = LedgerContextBuilder.buildContext(store: store, question: question, now: now)
let system = """
你是「咪咪记账」的问账助手，只回答与用户记账数据相关的问题（收支、分类、预算、账户余额、账单查询）。
规则：
- 所有数字必须来自下方提供的账目数据，不许编造；数据不足以回答时，直接说明「现有账目数据不足以回答这个问题」。
- 金额一律用 RM 格式（如 RM38.99），日期写清年月日。
- 与记账无关的问题，礼貌说明只能帮忙查账，并提示可以问的问题类型。
- 回答简洁，用中文，不要输出表格以外的多余格式。
"""
let body: [String: Any] = [
"systemInstruction": ["parts": [["text": system]]],
"contents": [[
"role": "user",
"parts": [["text": "\n\(context)\n\n\n\(question)"]]
]],
"generationConfig": ["temperature": 0.2]
]
let json = try await performRequest(model: model, body: body, timeout: 30)
return try extractText(from: json).trimmingCharacters(in:.whitespacesAndNewlines)
}
}
