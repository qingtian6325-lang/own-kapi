import Foundation
import Combine

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
public final class KapiStore: ObservableObject {
    public static let shared = KapiStore()

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
    @Published public var hideAmounts: Bool = false
    @Published public var reimbursableAmount: Double = 0.00
    @Published public var userNickname: String = "小金主"

    private let inMemory: Bool
    private let storageURL: URL

    public init(inMemory: Bool = false) {
        self.inMemory = inMemory
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.storageURL = docDir.appendingPathComponent("kapi_money_state_v2.json")

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
        appendAuditLog(for: item, action: .created, loggedAt: loggedAt)
        saveState()
    }

    public func updateTransaction(_ updated: TransactionItem, at loggedAt: Date = Date()) {
        guard let idx = transactions.firstIndex(where: { $0.id == updated.id }) else { return }
        let old = transactions[idx]
        applyBalanceEffect(for: old, multiplier: -1.0)
        transactions[idx] = updated
        transactions.sort(by: { $0.date > $1.date })
        applyBalanceEffect(for: updated, multiplier: 1.0)
        appendAuditLog(for: updated, action: .updated, loggedAt: loggedAt)
        saveState()
    }

    public func deleteTransaction(id: UUID, at loggedAt: Date = Date()) {
        guard let idx = transactions.firstIndex(where: { $0.id == id }) else { return }
        let removed = transactions.remove(at: idx)
        applyBalanceEffect(for: removed, multiplier: -1.0)
        appendAuditLog(for: removed, action: .deleted, loggedAt: loggedAt)
        saveState()
    }

    public func updateAccountBalance(accountId: String, newBalance: Double) {
        guard let idx = accounts.firstIndex(where: { $0.id == accountId }) else { return }
        let oldBalance = accounts[idx].balance
        let roundedNew = (newBalance * 100.0).rounded() / 100.0
        accounts[idx].balance = roundedNew
        let delta = roundedNew - oldBalance
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

    /// Imports Kapi Money dual-table CSV text and reconciles account balances & audit logs
    @discardableResult
    public func importKapiCSV(_ csvText: String, replaceExisting: Bool = false) -> Int {
        let parsed = KapiCSVService.parseKapiCSV(csvText)
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

    public func exportKapiCSV() -> String {
        KapiCSVService.exportKapiCSV(transactions: transactions)
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
        switch tx.type {
        case .expense:
            if let accId = tx.accountId, let idx = accounts.firstIndex(where: { $0.id == accId }) {
                accounts[idx].balance = ((accounts[idx].balance - netAmount * multiplier) * 100.0).rounded() / 100.0
            }
        case .income:
            if let accId = tx.accountId, let idx = accounts.firstIndex(where: { $0.id == accId }) {
                accounts[idx].balance = ((accounts[idx].balance + netAmount * multiplier) * 100.0).rounded() / 100.0
            }
        case .transfer:
            if let fromId = tx.accountId, let fromIdx = accounts.firstIndex(where: { $0.id == fromId }) {
                accounts[idx: fromIdx].balance = ((accounts[fromIdx].balance - netAmount * multiplier) * 100.0).rounded() / 100.0
            }
            if let toId = tx.targetAccountId, let toIdx = accounts.firstIndex(where: { $0.id == toId }) {
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
            loggedAt: loggedAt
        )
        auditLogs.insert(log, at: 0)
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
