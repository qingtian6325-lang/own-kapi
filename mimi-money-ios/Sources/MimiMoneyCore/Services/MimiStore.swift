import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

public struct PersistedAppState: Codable, Sendable {
    public var ledgers: [LedgerItem]
    public var currentLedgerId: String
    public var accounts: [AccountItem]
    public var transactions: [TransactionItem]
    public var auditLogs: [AccountAuditLog]
    public var expenseCategories: [CategoryGroup]
    public var incomeCategories: [CategoryGroup]
    public var tags: [String]
}

@MainActor
public final class MimiStore: ObservableObject {
    public static let shared = MimiStore()

    @Published public var ledgers: [LedgerItem]
    @Published public var currentLedgerId: String
    @Published public var accounts: [AccountItem]
    @Published public var transactions: [TransactionItem]
    @Published public var auditLogs: [AccountAuditLog]
    @Published public var expenseCategories: [CategoryGroup]
    @Published public var incomeCategories: [CategoryGroup]
    @Published public var tags: [String]
    @Published public var pendingEditTransactionId: UUID?
    @Published public var pendingShortcutSnippetBill: TransactionItem?
    @Published public var pendingScanTransactions: [TransactionItem] = []
    @Published public var isRecordSheetPresented: Bool = false
    @Published public var hideAmounts: Bool = false
    @Published public var reimbursableAmount: Double = 0.00
    @Published public var userNickname: String = "jinghao"
    @Published public var hapticsEnabled: Bool = true
    @Published public var scheduledTransactions: [ScheduledTransactionItem] = []

    private let inMemory: Bool
    private let storageURL: URL
    private let pendingScansURL: URL
    private static var receiptMemoryCache: [String: Data] = [:]

    // MARK: - Receipt Image Persistence
    public var receiptsDirectoryURL: URL {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let receiptsURL = docDir.appendingPathComponent("Receipts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: receiptsURL.path) {
            try? FileManager.default.createDirectory(at: receiptsURL, withIntermediateDirectories: true)
        }
        return receiptsURL
    }

    /// Saves receipt image with cross-sandbox resilience.
    /// If image data is reasonably sized (<= 350KB), stores inline base64 string
    /// so AppIntents / Shortcuts running in external extension sandboxes NEVER lose
    /// access to the image when viewed in the main app.
    public func saveReceiptImage(data: Data) -> String {
        var finalData = data
        #if canImport(UIKit)
        if data.count > 180_000, let uiImg = UIImage(data: data) {
            // Resize and compress for lightweight persistence
            let maxDim: CGFloat = 1200
            let size = uiImg.size
            if size.width > maxDim || size.height > maxDim {
                let ratio = min(maxDim / size.width, maxDim / size.height)
                let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let resized = renderer.image { _ in
                    uiImg.draw(in: CGRect(origin: .zero, size: newSize))
                }
                if let compressed = resized.jpegData(compressionQuality: 0.65) {
                    finalData = compressed
                }
            } else if let compressed = uiImg.jpegData(compressionQuality: 0.70) {
                finalData = compressed
            }
        }
        #endif

        let filename = "receipt_\(UUID().uuidString.prefix(12)).jpg"
        let fileURL = receiptsDirectoryURL.appendingPathComponent(filename)
        try? finalData.write(to: fileURL, options: .atomic)
        Self.receiptMemoryCache[filename] = finalData

        // Also write to temporary and caches directory as fallback
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        try? finalData.write(to: tempURL, options: .atomic)

        // For guaranteed cross-sandbox / shortcut persistence, return base64 if <= 350KB
        if finalData.count <= 350_000 {
            let base64String = "base64:\(finalData.base64EncodedString())"
            Self.receiptMemoryCache[base64String] = finalData
            return base64String
        }

        return filename
    }

    /// Robust loader for receipt images: supports base64 inline, memory cache,
    /// documents folder, temporary directories, caches, and app group containers.
    public func loadReceiptImageData(filename: String) -> Data? {
        let clean = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        // 1. Direct Base64 prefix
        if clean.hasPrefix("base64:") {
            let base64Payload = String(clean.dropFirst(7))
            if let decoded = Data(base64Encoded: base64Payload, options: .ignoreUnknownCharacters) {
                return decoded
            }
        }
        if clean.hasPrefix("data:image/") && clean.contains(";base64,") {
            let components = clean.components(separatedBy: ";base64,")
            if components.count == 2, let decoded = Data(base64Encoded: components[1], options: .ignoreUnknownCharacters) {
                return decoded
            }
        }

        // 2. Memory cache
        if let cached = Self.receiptMemoryCache[clean] {
            return cached
        }

        // 3. Absolute path on disk (must actually exist on filesystem)
        if (clean.hasPrefix("/") || clean.contains(":\\")) && FileManager.default.fileExists(atPath: clean) {
            if let diskData = try? Data(contentsOf: URL(fileURLWithPath: clean)) {
                Self.receiptMemoryCache[clean] = diskData
                return diskData
            }
        }

        // 4. Standard receipts directory (must actually exist)
        let standardURL = receiptsDirectoryURL.appendingPathComponent(clean)
        if FileManager.default.fileExists(atPath: standardURL.path),
           let diskData = try? Data(contentsOf: standardURL) {
            Self.receiptMemoryCache[clean] = diskData
            return diskData
        }

        // 5. Look up by lastPathComponent in documents, temp, caches, app group if it looks like a filename
        let lastComponent = URL(fileURLWithPath: clean).lastPathComponent
        if lastComponent.contains(".") {
            let candidateURLs = [
                receiptsDirectoryURL.appendingPathComponent(lastComponent),
                URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(lastComponent),
                FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(lastComponent),
                FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(lastComponent),
                FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mimi.money")?.appendingPathComponent("Receipts/\(lastComponent)")
            ].compactMap { $0 }

            for cand in candidateURLs {
                if FileManager.default.fileExists(atPath: cand.path),
                   let diskData = try? Data(contentsOf: cand) {
                    Self.receiptMemoryCache[clean] = diskData
                    return diskData
                }
            }
        }

        // 6. Base64 fallback (supports bare Base64 including standard JPEG /9j/ headers)
        if let bareDecoded = Data(base64Encoded: clean, options: .ignoreUnknownCharacters), !bareDecoded.isEmpty {
            Self.receiptMemoryCache[clean] = bareDecoded
            return bareDecoded
        }

        return nil
    }

    public func deleteReceiptImage(filename: String) {
        let clean = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        Self.receiptMemoryCache.removeValue(forKey: clean)
        if !clean.hasPrefix("base64:") {
            let fileURL = clean.hasPrefix("/") ? URL(fileURLWithPath: clean) : receiptsDirectoryURL.appendingPathComponent(clean)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    public init(inMemory: Bool = false) {
        self.inMemory = inMemory
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.storageURL = docDir.appendingPathComponent("mimi_money_state_v2.json")
        self.pendingScansURL = docDir.appendingPathComponent("mimi_pending_scans_v1.json")

        if !inMemory,
           let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode(PersistedAppState.self, from: data) {
            self.ledgers = decoded.ledgers
            self.currentLedgerId = decoded.currentLedgerId
            self.accounts = decoded.accounts
            self.transactions = decoded.transactions
            self.auditLogs = decoded.auditLogs
            self.expenseCategories = decoded.expenseCategories
            self.incomeCategories = decoded.incomeCategories
            self.tags = decoded.tags
        } else if inMemory {
            // Unit test in-memory store uses deterministic test dataset
            let initial = Self.makeDemoAppState()
            self.ledgers = initial.ledgers
            self.currentLedgerId = initial.currentLedgerId
            self.accounts = initial.accounts
            self.transactions = initial.transactions
            self.auditLogs = initial.auditLogs
            self.expenseCategories = initial.expenseCategories
            self.incomeCategories = initial.incomeCategories
            self.tags = initial.tags
            self.reimbursableAmount = 1000.00
        } else {
            // Production App default: completely empty transactions, audit logs, and 0.00 account balances
            let empty = Self.makeCleanEmptyAppState()
            self.ledgers = empty.ledgers
            self.currentLedgerId = empty.currentLedgerId
            self.accounts = empty.accounts
            self.transactions = empty.transactions
            self.auditLogs = empty.auditLogs
            self.expenseCategories = empty.expenseCategories
            self.incomeCategories = empty.incomeCategories
            self.tags = empty.tags
            self.reimbursableAmount = 0.00
        }
        if !inMemory,
           let data = try? Data(contentsOf: pendingScansURL),
           let decoded = try? JSONDecoder().decode([TransactionItem].self, from: data) {
            self.pendingScanTransactions = decoded
        }
        recalculateAllAccountBalances()
    }

    public var currentLedger: LedgerItem {
        get {
            ledgers.first(where: { $0.id == currentLedgerId }) ?? DefaultCatalog.defaultLedger()
        }
        set {
            if let idx = ledgers.firstIndex(where: { $0.id == newValue.id }) {
                ledgers[idx] = newValue
                saveState()
            }
        }
    }

    public func addTransaction(_ item: TransactionItem, at loggedAt: Date = Date()) {
        transactions.insert(item, at: 0)
        transactions.sort(by: { $0.date > $1.date })
        applyBalanceEffect(for: item, multiplier: 1.0)
        recalculateAllAccountBalances()
        appendAuditLog(for: item, action: .created, loggedAt: loggedAt)
        saveState()
    }

    // MARK: - Pending Shortcut Scan Staging （确认型识别流程的待确认暂存区）
    //
    // v1.1.2 起「识别账单」改为确认型呈现：识别结果先暂存到这里
    // （isConfirmed=false），不进 transactions，因此不影响余额、列表与统计；
    // 用户在系统确认卡上点「确认」后才由 finalize 路径正式落盘，点「修改」
    // 则由 edit 路径以未确认状态转入正式记录并进 App 编辑，取消/下滑则永不落盘。
    // 每个暂存项只能被消费一次（consume 后即删除），保证绝不重复记账。
    // 暂存单独落盘到 mimi_pending_scans_v1.json（不并入 PersistedAppState，
    // 避免旧存档 Codable 解码兼容风险），因为捷徑 Intent 与 App 可能运行在
    // 不同进程，暂存必须持久化才能跨进程接力。

    public func stagePendingScan(_ item: TransactionItem) {
        if let idx = pendingScanTransactions.firstIndex(where: { $0.id == item.id }) {
            pendingScanTransactions[idx] = item
        } else {
            pendingScanTransactions.append(item)
        }
        // 只保留最近 20 条，防取消确认后残留的孤儿暂存无限累积
        if pendingScanTransactions.count > 20 {
            pendingScanTransactions.removeFirst(pendingScanTransactions.count - 20)
        }
        savePendingScans()
    }

    public func pendingScan(id: UUID) -> TransactionItem? {
        pendingScanTransactions.first(where: { $0.id == id })
    }

    /// 原子消费一个暂存项：取出并删除。同一 id 第二次调用必然返回 nil（单次消费/幂等）。
    @discardableResult
    public func consumePendingScan(id: UUID) -> TransactionItem? {
        guard let idx = pendingScanTransactions.firstIndex(where: { $0.id == id }) else { return nil }
        let item = pendingScanTransactions.remove(at: idx)
        savePendingScans()
        return item
    }

    public func discardPendingScan(id: UUID) {
        pendingScanTransactions.removeAll(where: { $0.id == id })
        savePendingScans()
    }

    private func savePendingScans() {
        guard !inMemory else { return }
        if let data = try? JSONEncoder().encode(pendingScanTransactions) {
            try? data.write(to: pendingScansURL, options: .atomic)
        }
    }

    public func updateTransaction(_ updated: TransactionItem, at loggedAt: Date = Date()) {
        guard let idx = transactions.firstIndex(where: { $0.id == updated.id }) else { return }
        let old = transactions[idx]
        applyBalanceEffect(for: old, multiplier: -1.0)
        transactions[idx] = updated
        transactions.sort(by: { $0.date > $1.date })
        applyBalanceEffect(for: updated, multiplier: 1.0)
        recalculateAllAccountBalances()
        appendAuditLog(for: updated, action: .updated, loggedAt: loggedAt)
        saveState()
    }

    public func deleteTransaction(id: UUID, at loggedAt: Date = Date()) {
        guard let idx = transactions.firstIndex(where: { $0.id == id }) else { return }
        let removed = transactions.remove(at: idx)
        applyBalanceEffect(for: removed, multiplier: -1.0)
        recalculateAllAccountBalances()
        appendAuditLog(for: removed, action: .deleted, loggedAt: loggedAt)
        saveState()
    }

    public func recalculateAllAccountBalances() {
        for idx in accounts.indices {
            let delta = accountTransactionDelta(accountId: accounts[idx].id)
            accounts[idx].balance = ((accounts[idx].initialBalance + delta) * 100.0).rounded() / 100.0
        }
    }

    public func accountTransactionDelta(accountId: String) -> Double {
        let acc = accounts.first(where: { $0.id == accountId })
        let accName = acc?.name ?? accountId
        var delta: Double = 0.0
        for tx in transactions {
            let net = max(0.0, tx.amount - tx.discountAmount - tx.refundAmount)
            let txSrcId = tx.accountId ?? DefaultCatalog.resolveAccountId(from: tx.accountName)
            let isSrc = txSrcId == accountId || tx.accountId == accountId || tx.accountName == accName
            let txDstId = tx.targetAccountId ?? (tx.targetAccountName.map { DefaultCatalog.resolveAccountId(from: $0) } ?? nil)
            let isDst = txDstId == accountId || tx.targetAccountId == accountId || tx.targetAccountName == accName

            if tx.type == .expense && isSrc {
                delta -= net
            } else if tx.type == .income && isSrc {
                delta += net
            } else if tx.type == .transfer {
                if isSrc {
                    delta -= net
                }
                if isDst {
                    delta += net
                }
            }
        }
        return ((delta * 100.0).rounded()) / 100.0
    }

    public func setAccountInitialBalance(accountId: String, initialBalance: Double) {
        guard let idx = accounts.firstIndex(where: { $0.id == accountId }) else { return }
        let roundedInit = (initialBalance * 100.0).rounded() / 100.0
        accounts[idx].initialBalance = roundedInit
        let delta = accountTransactionDelta(accountId: accountId)
        let newCurrent = ((roundedInit + delta) * 100.0).rounded() / 100.0
        accounts[idx].balance = newCurrent

        let log = AccountAuditLog(
            accountId: accountId,
            action: .updated,
            transactionType: .income,
            categoryTitle: "设定期初资金 | \(accounts[idx].name)",
            note: "设定记账前起始资金为 RM\(String(format: "%.2f", roundedInit))",
            amount: roundedInit,
            balanceAfter: newCurrent,
            billDate: Date(),
            loggedAt: Date()
        )
        auditLogs.insert(log, at: 0)
        saveState()
    }

    public func setAccountInitialBalance(accountName: String, initialBalance: Double) {
        if let match = accounts.first(where: { $0.name == accountName || $0.id == accountName }) {
            setAccountInitialBalance(accountId: match.id, initialBalance: initialBalance)
        }
    }

    public func updateAccountBalance(accountId: String, newBalance: Double) {
        guard let idx = accounts.firstIndex(where: { $0.id == accountId }) else { return }
        let oldBalance = accounts[idx].balance
        let roundedNew = (newBalance * 100.0).rounded() / 100.0
        accounts[idx].balance = roundedNew
        let delta = roundedNew - oldBalance
        let transDelta = accountTransactionDelta(accountId: accountId)
        accounts[idx].initialBalance = ((roundedNew - transDelta) * 100.0).rounded() / 100.0
        let log = AccountAuditLog(
            accountId: accountId,
            action: .updated,
            transactionType: delta >= 0 ? .income : .expense,
            categoryTitle: "修改余额 | \(accounts[idx].name)",
            note: "手动修改账户余额",
            amount: abs(delta),
            balanceAfter: roundedNew,
            billDate: Date(),
            loggedAt: Date()
        )
        auditLogs.insert(log, at: 0)
        saveState()
    }

    public func updateAccountBalance(accountName: String, newBalance: Double) {
        if let match = accounts.first(where: { $0.name == accountName || $0.id == accountName }) {
            updateAccountBalance(accountId: match.id, newBalance: newBalance)
        }
    }

    public func addAccount(_ account: AccountItem) {
        accounts.append(account)
        saveState()
    }

    public func deleteAccount(accountId: String) {
        guard accounts.count > 1 else { return }
        accounts.removeAll(where: { $0.id == accountId })
        saveState()
    }

    public func addPrimaryCategory(name: String, type: TransactionType, iconName: String, useFirstCharIcon: Bool) {
        let newGroup = CategoryGroup(
            id: "custom_\(UUID().uuidString.prefix(8))",
            name: name,
            type: type,
            iconName: iconName,
            useFirstCharIcon: useFirstCharIcon,
            isCustom: true,
            subCategories: [],
            sortOrder: (type == .expense ? expenseCategories.count : incomeCategories.count)
        )
        if type == .expense {
            expenseCategories.append(newGroup)
        } else {
            incomeCategories.append(newGroup)
        }
        saveState()
    }

    public func addPrimaryCategory(type: TransactionType, name: String, iconName: String, useFirstCharIcon: Bool) {
        addPrimaryCategory(name: name, type: type, iconName: iconName, useFirstCharIcon: useFirstCharIcon)
    }

    public func addSubCategory(to groupId: String, name: String, iconName: String) {
        if let idx = expenseCategories.firstIndex(where: { $0.id == groupId }) {
            let sub = SubCategory(
                id: "sub_\(UUID().uuidString.prefix(8))",
                name: name,
                iconName: iconName,
                sortOrder: expenseCategories[idx].subCategories.count
            )
            expenseCategories[idx].subCategories.append(sub)
            saveState()
            return
        }
        if let idx = incomeCategories.firstIndex(where: { $0.id == groupId }) {
            let sub = SubCategory(
                id: "sub_\(UUID().uuidString.prefix(8))",
                name: name,
                iconName: iconName,
                sortOrder: incomeCategories[idx].subCategories.count
            )
            incomeCategories[idx].subCategories.append(sub)
            saveState()
        }
    }

    public func addSubcategory(
        toGroupId: String,
        type: TransactionType,
        name: String,
        iconName: String,
        useFirstCharIcon: Bool
    ) {
        addSubCategory(to: toGroupId, name: name, iconName: iconName)
    }

    public var monthlyBudgetTotal: Double {
        get { currentLedger.monthlyBudget }
        set {
            var ledger = currentLedger
            ledger.monthlyBudget = newValue
            currentLedger = ledger
        }
    }

    // MARK: - Ledger Management Functions
    public func addLedger(name: String, currency: CurrencyCode = .myr, monthlyBudget: Double = 3000.0) {
        let newLedger = LedgerItem(
            id: "ledger_\(UUID().uuidString.prefix(8))",
            name: name,
            currency: currency,
            monthlyBudget: monthlyBudget,
            categoryBudgets: DefaultCatalog.defaultLedger().categoryBudgets
        )
        ledgers.append(newLedger)
        currentLedgerId = newLedger.id
        saveState()
    }

    public func renameLedger(id: String, newName: String) {
        guard let idx = ledgers.firstIndex(where: { $0.id == id }) else { return }
        ledgers[idx].name = newName
        saveState()
    }

    public func updateLedgerBudget(id: String, newBudget: Double) {
        guard let idx = ledgers.firstIndex(where: { $0.id == id }) else { return }
        ledgers[idx].monthlyBudget = max(0.0, newBudget)
        saveState()
    }

    public func deleteLedger(id: String) {
        guard ledgers.count > 1 else { return }
        ledgers.removeAll(where: { $0.id == id })
        if currentLedgerId == id {
            currentLedgerId = ledgers.first?.id ?? "ledger_main"
        }
        saveState()
    }

    public func switchLedger(id: String) {
        if ledgers.contains(where: { $0.id == id }) {
            currentLedgerId = id
            saveState()
        }
    }

    // MARK: - Tag Management Functions
    public func addTag(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        saveState()
    }

    public func deleteTag(_ name: String) {
        tags.removeAll(where: { $0 == name })
        saveState()
    }

    public func transactions(forTag tag: String) -> [TransactionItem] {
        transactions.filter { $0.tags.contains(tag) }
    }

    // MARK: - Scheduled Bookkeeping Functions
    public func addScheduledTransaction(_ item: ScheduledTransactionItem) {
        scheduledTransactions.append(item)
        saveState()
    }

    public func deleteScheduledTransaction(id: UUID) {
        scheduledTransactions.removeAll(where: { $0.id == id })
        saveState()
    }

    public func toggleScheduledTransaction(id: UUID) {
        guard let idx = scheduledTransactions.firstIndex(where: { $0.id == id }) else { return }
        scheduledTransactions[idx].isEnabled.toggle()
        saveState()
    }

    public func executeScheduledTransactionNow(id: UUID) {
        guard let item = scheduledTransactions.first(where: { $0.id == id }) else { return }
        let tx = TransactionItem(
            ledgerId: currentLedgerId,
            type: item.type,
            amount: item.amount,
            currency: currentLedger.currency,
            primaryCategoryId: item.categoryPath,
            accountId: DefaultCatalog.resolveAccountId(from: item.accountName),
            note: "【定时入账】\(item.title)"
        )
        addTransaction(tx)
    }

    // MARK: - User Settings
    public func setNickname(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            userNickname = trimmed
            saveState()
        }
    }

    public func monthlyBudgetRemaining(year: Int, month: Int) -> Double {
        max(0.0, monthlyBudgetTotal - monthlyExpenseTotal(year: year, month: month))
    }

    public var currentLedgerName: String {
        get { currentLedger.name }
        set {
            if let found = ledgers.first(where: { $0.name == newValue || $0.id == newValue }) {
                currentLedgerId = found.id
                saveState()
            }
        }
    }

    public var categoryBudgets: [CategoryBudgetItem] {
        currentLedger.categoryBudgets
    }

    public func categorySpent(for categoryName: String, year: Int, month: Int) -> Double {
        let cal = Calendar(identifier: .gregorian)
        return transactions.reduce(0.0) { acc, tx in
            guard tx.ledgerId == currentLedgerId,
                  tx.includeInStats,
                  tx.type == .expense else { return acc }
            let comps = cal.dateComponents([.year, .month], from: tx.date)
            guard comps.year == year && comps.month == month else { return acc }
            let primaryName = tx.categoryPath.components(separatedBy: "-").first ?? tx.categoryPath
            guard primaryName == categoryName || tx.primaryCategoryId == categoryName else { return acc }
            let net = max(0.0, tx.amount - tx.discountAmount - tx.refundAmount)
            return acc + net
        }
    }

    public func setCustomDailyBudget(dateKey: String, amount: Double) {
        var ledger = currentLedger
        ledger.customDailyBudgets[dateKey] = max(0.0, amount)
        currentLedger = ledger
        saveState()
    }

    public func updateMonthlyBudget(_ newBudget: Double) {
        var ledger = currentLedger
        ledger.monthlyBudget = max(0.0, newBudget)
        currentLedger = ledger
        saveState()
    }

    public func setCategoryBudget(categoryName: String, monthlyLimit: Double, iconName: String = "🏷️") {
        var ledger = currentLedger
        if let idx = ledger.categoryBudgets.firstIndex(where: { $0.categoryName == categoryName }) {
            ledger.categoryBudgets[idx].monthlyLimit = max(0.0, monthlyLimit)
        } else {
            let newId = "cb_\(UUID().uuidString.prefix(6))"
            let newItem = CategoryBudgetItem(
                id: newId,
                categoryId: "exp_\(categoryName)",
                categoryName: categoryName,
                iconName: iconName,
                monthlyLimit: max(0.0, monthlyLimit),
                sortOrder: ledger.categoryBudgets.count
            )
            ledger.categoryBudgets.append(newItem)
        }
        currentLedger = ledger
        saveState()
    }

    public func removeCategoryBudget(categoryName: String) {
        var ledger = currentLedger
        ledger.categoryBudgets.removeAll(where: { $0.categoryName == categoryName })
        currentLedger = ledger
        saveState()
    }

    public var netWorth: Double { netWorthTotal() }

    public var totalAssets: Double {
        accounts.filter { !$0.isLiability }.reduce(0.0) { $0 + $1.balance }
    }

    public var totalLiabilities: Double {
        accounts.filter { $0.isLiability }.reduce(0.0) { $0 + $1.balance }
    }

    public var pendingReimbursementAmount: Double { reimbursableAmount }

    public var recordedDaysCount: Int {
        let cal = Calendar(identifier: .gregorian)
        let uniqueDays = Set(transactions.map { cal.startOfDay(for: $0.date) })
        return uniqueDays.count
    }

    public var totalRecordsCount: Int {
        transactions.count
    }

    public var streakDaysCount: Int {
        transactions.isEmpty ? 0 : 1
    }

    /// Imports Mimi Money dual-table CSV text and reconciles account balances & audit logs
    @discardableResult
    public func importMimiCSV(_ csvText: String, replaceExisting: Bool = false) -> Int {
        let parsed = MimiCSVService.parseMimiCSV(csvText)
        guard !parsed.isEmpty else { return 0 }
        if replaceExisting {
            transactions = []
            auditLogs = []
            for idx in accounts.indices {
                accounts[idx].balance = 0.0
            }
        }
        // Apply chronologically so audit logs & balances accumulate accurately
        for item in parsed.sorted(by: { $0.date < $1.date }) {
            addTransaction(item, at: item.date)
        }
        saveState()
        return parsed.count
    }

    public func exportMimiCSV(startDate: Date? = nil, endDate: Date? = nil) -> String {
        let filtered: [TransactionItem]
        if let start = startDate, let end = endDate {
            filtered = transactions.filter { $0.date >= start && $0.date <= end }
        } else if let start = startDate {
            filtered = transactions.filter { $0.date >= start }
        } else if let end = endDate {
            filtered = transactions.filter { $0.date <= end }
        } else {
            filtered = transactions
        }
        return MimiCSVService.exportMimiCSV(transactions: filtered)
    }

    public func exportMimiCSV() -> String {
        exportMimiCSV(startDate: nil, endDate: nil)
    }

    public func groupedTransactionsByDay() -> [(date: Date, items: [TransactionItem])] {
        let cal = Calendar(identifier: .gregorian)
        let filtered = transactions.filter { $0.ledgerId == currentLedgerId }
        var buckets: [Date: [TransactionItem]] = [:]
        for tx in filtered {
            let dayStart = cal.startOfDay(for: tx.date)
            buckets[dayStart, default: []].append(tx)
        }
        return buckets
            .map { (date: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    public func auditLogs(for accountName: String) -> [AccountAuditLog] {
        let targetId = accounts.first(where: { $0.name == accountName || $0.id == accountName })?.id ?? accountName
        return auditLogs.filter { $0.accountId == targetId || $0.accountId == accountName }
    }

    public func monthlyExpenseTotal(year: Int, month: Int) -> Double {
        let cal = Calendar(identifier: .gregorian)
        return transactions.reduce(0.0) { acc, tx in
            guard tx.ledgerId == currentLedgerId,
                  tx.includeInStats,
                  tx.type == .expense else { return acc }
            let comps = cal.dateComponents([.year, .month], from: tx.date)
            guard comps.year == year && comps.month == month else { return acc }
            let net = max(0.0, tx.amount - tx.discountAmount - tx.refundAmount)
            return acc + net
        }
    }

    public func monthlyIncomeTotal(year: Int, month: Int) -> Double {
        let cal = Calendar(identifier: .gregorian)
        return transactions.reduce(0.0) { acc, tx in
            guard tx.ledgerId == currentLedgerId,
                  tx.includeInStats,
                  tx.type == .income else { return acc }
            let comps = cal.dateComponents([.year, .month], from: tx.date)
            guard comps.year == year && comps.month == month else { return acc }
            return acc + tx.amount
        }
    }

    public func netWorthTotal() -> Double {
        accounts.reduce(0.0) { $0 + ($1.isLiability ? -$1.balance : $1.balance) }
    }

    public func categoryTitle(for tx: TransactionItem) -> String {
        if tx.type == .transfer { return "转账" }
        let groups = tx.type == .expense ? expenseCategories : incomeCategories
        guard let group = groups.first(where: { $0.id == tx.primaryCategoryId }) else {
            return tx.primaryCategoryId
        }
        if let subId = tx.subCategoryId,
           let sub = group.subCategories.first(where: { $0.id == subId }) {
            return "\(group.name)-\(sub.name)"
        }
        return group.name
    }

    public func categoryIcon(for tx: TransactionItem) -> String {
        if tx.type == .transfer { return "⇄" }
        let groups = tx.type == .expense ? expenseCategories : incomeCategories
        guard let group = groups.first(where: { $0.id == tx.primaryCategoryId }) else {
            return "💰"
        }
        if let subId = tx.subCategoryId,
           let sub = group.subCategories.first(where: { $0.id == subId }) {
            return sub.displayBadgeToken
        }
        return group.displayBadgeToken
    }

    public func accountName(for accountId: String?) -> String {
        guard let accountId,
              let acc = accounts.first(where: { $0.id == accountId }) else {
            return "无账户"
        }
        return acc.name
    }

    public func resetToDemoData() {
        let demo = Self.makeDemoAppState()
        self.ledgers = demo.ledgers
        self.currentLedgerId = demo.currentLedgerId
        self.accounts = demo.accounts
        self.transactions = demo.transactions
        self.auditLogs = demo.auditLogs
        self.expenseCategories = demo.expenseCategories
        self.incomeCategories = demo.incomeCategories
        self.tags = demo.tags
        saveState()
    }

    public func clearAllDemoTransactions() {
        resetToCleanEmpty()
    }

    public func resetToCleanEmpty() {
        let clean = Self.makeCleanEmptyAppState()
        self.ledgers = clean.ledgers
        self.currentLedgerId = clean.currentLedgerId
        self.accounts = clean.accounts
        self.transactions = []
        self.auditLogs = []
        self.reimbursableAmount = 0.0
        self.expenseCategories = clean.expenseCategories
        self.incomeCategories = clean.incomeCategories
        self.tags = clean.tags
        saveState()
    }

    public static func makeCleanEmptyAppState() -> PersistedAppState {
        let zeroAccounts = DefaultCatalog.defaultAccounts().map { acc in
            AccountItem(
                id: acc.id,
                name: acc.name,
                subtitle: acc.subtitle,
                badgeText: acc.badgeText,
                iconName: acc.iconName,
                balance: 0.00,
                isLiability: acc.isLiability
            )
        }
        return PersistedAppState(
            ledgers: [DefaultCatalog.defaultLedger()],
            currentLedgerId: "ledger_main",
            accounts: zeroAccounts,
            transactions: [],
            auditLogs: [],
            expenseCategories: DefaultCatalog.standardExpenseCategories(),
            incomeCategories: DefaultCatalog.standardIncomeCategories(),
            tags: ["报销", "旅行", "固定支出", "家庭"]
        )
    }

    private func applyBalanceEffect(for tx: TransactionItem, multiplier: Double) {
        let netAmount = max(0.0, tx.amount - tx.discountAmount - tx.refundAmount)
        let resolvedSrcId = tx.accountId ?? DefaultCatalog.resolveAccountId(from: tx.accountName)
        let resolvedDstId = tx.targetAccountId ?? (tx.targetAccountName.map { DefaultCatalog.resolveAccountId(from: $0) } ?? nil)

        switch tx.type {
        case .expense:
            if let accId = resolvedSrcId, let idx = accounts.firstIndex(where: { $0.id == accId || $0.name == tx.accountName }) {
                accounts[idx].balance = ((accounts[idx].balance - netAmount * multiplier) * 100.0).rounded() / 100.0
            }
        case .income:
            if let accId = resolvedSrcId, let idx = accounts.firstIndex(where: { $0.id == accId || $0.name == tx.accountName }) {
                accounts[idx].balance = ((accounts[idx].balance + netAmount * multiplier) * 100.0).rounded() / 100.0
            }
        case .transfer:
            if let fromId = resolvedSrcId, let fromIdx = accounts.firstIndex(where: { $0.id == fromId || $0.name == tx.accountName }) {
                accounts[fromIdx].balance = ((accounts[fromIdx].balance - netAmount * multiplier) * 100.0).rounded() / 100.0
            }
            if let toId = resolvedDstId, let toIdx = accounts.firstIndex(where: { $0.id == toId || $0.name == tx.targetAccountName }) {
                accounts[toIdx].balance = ((accounts[toIdx].balance + netAmount * multiplier) * 100.0).rounded() / 100.0
            }
        }
    }

    private func appendAuditLog(for tx: TransactionItem, action: AuditActionType, loggedAt: Date) {
        guard let accId = tx.accountId,
              let acc = accounts.first(where: { $0.id == accId }) else { return }
        let title = categoryTitle(for: tx).components(separatedBy: "-").last ?? categoryTitle(for: tx)
        let log = AccountAuditLog(
            accountId: accId,
            action: action,
            transactionType: tx.type,
            categoryTitle: "\(tx.type.rawValue) | \(title)",
            note: tx.note.isEmpty ? (action == .updated ? "账单编辑" : title) : tx.note,
            amount: max(0.0, tx.amount - tx.discountAmount - tx.refundAmount),
            balanceAfter: acc.balance,
            billDate: tx.date,
            loggedAt: loggedAt,
            transactionId: tx.id
        )
        auditLogs.insert(log, at: 0)
    }

    public func transaction(forAuditLog log: AccountAuditLog) -> TransactionItem? {
        if log.action == .deleted { return nil }
        if let tid = log.transactionId,
           let exact = transactions.first(where: { $0.id == tid }) {
            return exact
        }
        let accountNames: Set<String> = {
            var names: Set<String> = [log.accountId]
            if let acc = accounts.first(where: { $0.id == log.accountId || $0.name == log.accountId }) {
                names.insert(acc.id)
                names.insert(acc.name)
            }
            return names
        }()
        // Fallback for older logs without transactionId
        return transactions.first { tx in
            abs(tx.amount - log.amount) < 0.009
                && tx.type == log.transactionType
                && (accountNames.contains(tx.accountId ?? "") || accountNames.contains(tx.accountName))
                && abs(tx.date.timeIntervalSince(log.billDate)) < 86_400 * 2
        }
    }

    /// Reloads persisted state from disk. Used when the Shortcuts intent (running in a
    /// background process) has written new bills before the app UI is brought to front.
    public func reloadFromDisk() {
        guard !inMemory,
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode(PersistedAppState.self, from: data) else { return }
        ledgers = decoded.ledgers
        currentLedgerId = decoded.currentLedgerId
        accounts = decoded.accounts
        transactions = decoded.transactions
        auditLogs = decoded.auditLogs
        expenseCategories = decoded.expenseCategories
        incomeCategories = decoded.incomeCategories
        tags = decoded.tags
        if let pendingData = try? Data(contentsOf: pendingScansURL),
           let pendingDecoded = try? JSONDecoder().decode([TransactionItem].self, from: pendingData) {
            pendingScanTransactions = pendingDecoded
        }
        recalculateAllAccountBalances()
    }

    public func saveState() {
        guard !inMemory else { return }
        let state = PersistedAppState(
            ledgers: ledgers,
            currentLedgerId: currentLedgerId,
            accounts: accounts,
            transactions: transactions,
            auditLogs: auditLogs,
            expenseCategories: expenseCategories,
            incomeCategories: incomeCategories,
            tags: tags
        )
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }

    // Preloaded exact transactions and audit logs matching IMG_2240 - IMG_2262
    public static func makeDemoAppState() -> PersistedAppState {
        let cal = Calendar(identifier: .gregorian)
        func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)) ?? Date()
        }

        let txs: [TransactionItem] = [
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 38.78,
                currency: .myr,
                primaryCategoryId: "exp_transport",
                subCategoryId: "exp_trans_fuel",
                accountId: "acc_pbb",
                note: "",
                date: makeDate(2026, 11, 8, 21, 59)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 5.90,
                currency: .myr,
                primaryCategoryId: "exp_food",
                subCategoryId: "exp_food_restaurant",
                accountId: "acc_tng",
                note: "买egglab的东西",
                counterparty: "Near Me Voucher Eggette Lab",
                date: makeDate(2026, 11, 8, 16, 56)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 1000.00,
                currency: .myr,
                primaryCategoryId: "exp_invest",
                subCategoryId: nil,
                accountId: "acc_pbb",
                note: "",
                date: makeDate(2026, 11, 7, 23, 10)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 28.00,
                currency: .myr,
                primaryCategoryId: "exp_entertainment",
                subCategoryId: "exp_ent_offline",
                accountId: "acc_tng",
                note: "打麻将输钱",
                date: makeDate(2026, 11, 7, 23, 4)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                ledgerId: "ledger_main",
                type: .income,
                amount: 18.80,
                currency: .myr,
                primaryCategoryId: "inc_custom_transfer",
                subCategoryId: nil,
                accountId: "acc_tng",
                note: "买糖水 还我的钱",
                date: makeDate(2026, 11, 7, 20, 23)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 8.30,
                currency: .myr,
                primaryCategoryId: "exp_food",
                subCategoryId: "exp_food_restaurant",
                accountId: "acc_tng",
                note: "吃午餐",
                date: makeDate(2026, 11, 6, 13, 15)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
                ledgerId: "ledger_main",
                type: .income,
                amount: 1148.31,
                currency: .myr,
                primaryCategoryId: "inc_salary",
                subCategoryId: nil,
                accountId: "acc_pbb",
                note: "11月收入",
                date: makeDate(2026, 11, 6, 10, 0)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 1.80,
                currency: .myr,
                primaryCategoryId: "exp_food",
                subCategoryId: "exp_food_drink",
                accountId: "acc_tng",
                note: "wiwynn teh tarik",
                date: makeDate(2026, 11, 5, 15, 20)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
                ledgerId: "ledger_main",
                type: .income,
                amount: 29.60,
                currency: .myr,
                primaryCategoryId: "inc_custom_transfer",
                subCategoryId: nil,
                accountId: "acc_tng",
                note: "jingxian 还钱",
                date: makeDate(2026, 11, 5, 19, 0)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 10.70,
                currency: .myr,
                primaryCategoryId: "exp_food",
                subCategoryId: nil,
                accountId: "acc_tng",
                note: "转账给SOH YI YANG",
                date: makeDate(2026, 11, 4, 12, 32)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 47.34,
                currency: .myr,
                primaryCategoryId: "exp_transport",
                subCategoryId: "exp_trans_fuel",
                accountId: "acc_pbb",
                note: "在shell打油",
                date: makeDate(2026, 11, 3, 18, 10)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 7.00,
                currency: .myr,
                primaryCategoryId: "exp_food",
                subCategoryId: nil,
                accountId: "acc_tng",
                note: "转账给TAN JOO NI 吃苦瓜汤",
                date: makeDate(2026, 11, 3, 12, 12)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 0.70,
                currency: .myr,
                primaryCategoryId: "exp_food",
                subCategoryId: "exp_food_restaurant",
                accountId: "acc_tng",
                note: "RESTORAN FU CHUN 餐飲消費 喝中国茶",
                date: makeDate(2026, 11, 2, 12, 36)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 7.00,
                currency: .myr,
                primaryCategoryId: "exp_food",
                subCategoryId: nil,
                accountId: "acc_tng",
                note: "CONNIE MIXED RICE 下午杂菜饭",
                date: makeDate(2026, 11, 2, 12, 33)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000015")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 95.00,
                currency: .myr,
                primaryCategoryId: "exp_shopping",
                subCategoryId: "exp_shop_daily",
                accountId: "acc_pbb",
                note: "日常采购",
                date: makeDate(2026, 11, 1, 20, 15)
            ),
            TransactionItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000016")!,
                ledgerId: "ledger_main",
                type: .expense,
                amount: 12.00,
                currency: .myr,
                primaryCategoryId: "exp_food",
                subCategoryId: nil,
                accountId: "acc_tng",
                note: "Ausitn 消费",
                date: makeDate(2026, 11, 1, 21, 39)
            )
        ]

        // Exact audit logs from IMG_2259 & IMG_2260
        let logs: [AccountAuditLog] = [
            AccountAuditLog(
                accountId: "acc_tng",
                action: .deleted,
                transactionType: .expense,
                categoryTitle: "支出 | 零食甜品",
                note: "Near Me Voucher Eggette Lab 消费",
                amount: 5.90,
                balanceAfter: 68.62,
                billDate: makeDate(2026, 8, 11, 16, 56),
                loggedAt: makeDate(2026, 11, 9, 23, 55)
            ),
            AccountAuditLog(
                accountId: "acc_tng",
                action: .created,
                transactionType: .expense,
                categoryTitle: "支出 | 零食甜品",
                note: "Near Me Voucher Eggette Lab 消费",
                amount: 5.90,
                balanceAfter: 68.62,
                billDate: makeDate(2026, 8, 11, 16, 56),
                loggedAt: makeDate(2026, 11, 9, 23, 53)
            ),
            AccountAuditLog(
                accountId: "acc_tng",
                action: .created,
                transactionType: .expense,
                categoryTitle: "支出 | 餐厅",
                note: "买egglab的东西",
                amount: 5.90,
                balanceAfter: 68.62,
                billDate: makeDate(2026, 11, 8, 16, 56),
                loggedAt: makeDate(2026, 11, 9, 22, 27)
            ),
            AccountAuditLog(
                accountId: "acc_tng",
                action: .created,
                transactionType: .expense,
                categoryTitle: "支出 | 线下娱乐",
                note: "打麻将输钱",
                amount: 28.00,
                balanceAfter: 74.52,
                billDate: makeDate(2026, 11, 9, 22, 26),
                loggedAt: makeDate(2026, 11, 9, 22, 26)
            ),
            AccountAuditLog(
                accountId: "acc_tng",
                action: .updated,
                transactionType: .income,
                categoryTitle: "收入 | 别人转账",
                note: "账单编辑",
                amount: 14.80,
                balanceAfter: 83.72,
                billDate: makeDate(2026, 11, 5, 19, 0),
                loggedAt: makeDate(2026, 11, 9, 22, 24)
            )
        ]

        return PersistedAppState(
            ledgers: [DefaultCatalog.defaultLedger()],
            currentLedgerId: "ledger_main",
            accounts: DefaultCatalog.defaultAccounts(),
            transactions: txs,
            auditLogs: logs,
            expenseCategories: DefaultCatalog.standardExpenseCategories(),
            incomeCategories: DefaultCatalog.standardIncomeCategories(),
            tags: ["报销", "旅行", "固定支出", "家庭"]
        )
    }
}

private extension Array {
    subscript(idx index: Int) -> Element {
        get { self[index] }
        set { self[index] = newValue }
    }
}
