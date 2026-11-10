import Foundation

public enum CurrencyCode: String, CaseIterable, Codable, Sendable {
    case myr = "MYR"
    case cny = "CNY"
    case usd = "USD"
    case sgd = "SGD"

    public var symbol: String {
        switch self {
        case .myr: return "RM"
        case .cny: return "¥"
        case .usd: return "$"
        case .sgd: return "S$"
        }
    }
}

public enum TransactionType: String, CaseIterable, Codable, Sendable {
    case expense = "支出"
    case income = "收入"
    case transfer = "转账"

    public var title: String { rawValue }
}

public struct SubCategory: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var iconName: String
    public var useFirstCharIcon: Bool
    public var sortOrder: Int

    public init(
        id: String,
        name: String,
        iconName: String,
        useFirstCharIcon: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.useFirstCharIcon = useFirstCharIcon
        self.sortOrder = sortOrder
    }

    public var displayBadgeToken: String {
        if useFirstCharIcon, let first = name.first {
            return String(first)
        }
        return iconName
    }
}

public struct CategoryGroup: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var type: TransactionType
    public var iconName: String
    public var useFirstCharIcon: Bool
    public var isCustom: Bool
    public var subCategories: [SubCategory]
    public var sortOrder: Int

    public var subcategories: [SubCategory] {
        get { subCategories }
        set { subCategories = newValue }
    }

    public init(
        id: String,
        name: String,
        type: TransactionType,
        iconName: String,
        useFirstCharIcon: Bool = false,
        isCustom: Bool = false,
        subCategories: [SubCategory] = [],
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.iconName = iconName
        self.useFirstCharIcon = useFirstCharIcon
        self.isCustom = isCustom
        self.subCategories = subCategories
        self.sortOrder = sortOrder
    }

    public var displayBadgeToken: String {
        if useFirstCharIcon, let first = name.first {
            return String(first)
        }
        return iconName
    }
}

public struct AccountItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var subtitle: String
    public var badgeText: String?
    public var iconName: String
    public var balance: Double
    public var isLiability: Bool

    public init(
        id: String,
        name: String,
        subtitle: String,
        badgeText: String? = nil,
        iconName: String,
        balance: Double,
        isLiability: Bool = false
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.badgeText = badgeText
        self.iconName = iconName
        self.balance = balance
        self.isLiability = isLiability
    }
}

public enum AuditActionType: String, Codable, Sendable {
    case created = "记"
    case updated = "改"
    case deleted = "删"
}

public struct AccountAuditLog: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var accountId: String
    public var action: AuditActionType
    public var transactionType: TransactionType
    public var categoryTitle: String
    public var note: String
    public var amount: Double
    public var balanceAfter: Double
    public var billDate: Date
    public var loggedAt: Date

    public var title: String { categoryTitle }
    public var subtitle: String { note }
    public var deltaAmount: Double {
        transactionType == .income ? amount : -amount
    }

    public init(
        id: UUID = UUID(),
        accountId: String,
        action: AuditActionType,
        transactionType: TransactionType,
        categoryTitle: String,
        note: String,
        amount: Double,
        balanceAfter: Double,
        billDate: Date,
        loggedAt: Date = Date()
    ) {
        self.id = id
        self.accountId = accountId
        self.action = action
        self.transactionType = transactionType
        self.categoryTitle = categoryTitle
        self.note = note
        self.amount = amount
        self.balanceAfter = balanceAfter
        self.billDate = billDate
        self.loggedAt = loggedAt
    }
}

public struct TransactionItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var ledgerId: String
    public var type: TransactionType
    public var amount: Double
    public var currency: CurrencyCode
    public var primaryCategoryId: String
    public var subCategoryId: String?
    public var accountId: String?
    public var targetAccountId: String?
    public var note: String
    public var counterparty: String
    public var discountAmount: Double
    public var refundAmount: Double
    public var includeInStats: Bool
    public var includeInBudget: Bool
    public var tags: [String]
    public var attachmentPaths: [String]
    public var date: Date
    public var createdAt: Date
    public var isConfirmed: Bool
    private var customIconOverride: String?

    public var categoryPath: String {
        get {
            DefaultCatalog.resolveCategoryDisplay(
                primaryId: primaryCategoryId,
                subId: subCategoryId,
                type: type
            ).categoryPath
        }
        set {
            let resolved = DefaultCatalog.resolveCategoryIds(from: newValue, type: type)
            self.primaryCategoryId = resolved.primaryId
            self.subCategoryId = resolved.subId
        }
    }

    public var iconName: String {
        get {
            if let override = customIconOverride, !override.isEmpty {
                return override
            }
            return DefaultCatalog.resolveCategoryDisplay(
                primaryId: primaryCategoryId,
                subId: subCategoryId,
                type: type
            ).iconName
        }
        set {
            self.customIconOverride = newValue
        }
    }

    public var accountName: String {
        get {
            DefaultCatalog.resolveAccountName(from: accountId)
        }
        set {
            self.accountId = DefaultCatalog.resolveAccountId(from: newValue)
        }
    }

    public var ledgerName: String {
        get {
            ledgerId == "ledger_main" ? "Main Ledger" : ledgerId
        }
        set {
            self.ledgerId = (newValue == "Main Ledger") ? "ledger_main" : newValue
        }
    }

    public var receiptImageLabels: [String] {
        get { attachmentPaths }
        set { attachmentPaths = newValue }
    }

    public var refundOrCashback: Double? {
        get { refundAmount > 0 ? refundAmount : nil }
        set { refundAmount = newValue ?? 0.0 }
    }

    public init(
        id: UUID = UUID(),
        ledgerId: String = "ledger_main",
        type: TransactionType,
        amount: Double,
        currency: CurrencyCode = .myr,
        primaryCategoryId: String,
        subCategoryId: String? = nil,
        accountId: String? = nil,
        targetAccountId: String? = nil,
        note: String = "",
        counterparty: String = "",
        discountAmount: Double = 0.0,
        refundAmount: Double = 0.0,
        includeInStats: Bool = true,
        includeInBudget: Bool = true,
        tags: [String] = [],
        attachmentPaths: [String] = [],
        date: Date = Date(),
        createdAt: Date = Date(),
        isConfirmed: Bool = true,
        customIconOverride: String? = nil
    ) {
        self.id = id
        self.ledgerId = ledgerId
        self.type = type
        self.amount = amount
        self.currency = currency
        self.primaryCategoryId = primaryCategoryId
        self.subCategoryId = subCategoryId
        self.accountId = accountId
        self.targetAccountId = targetAccountId
        self.note = note
        self.counterparty = counterparty
        self.discountAmount = discountAmount
        self.refundAmount = refundAmount
        self.includeInStats = includeInStats
        self.includeInBudget = includeInBudget
        self.tags = tags
        self.attachmentPaths = attachmentPaths
        self.date = date
        self.createdAt = createdAt
        self.isConfirmed = isConfirmed
        self.customIconOverride = customIconOverride
    }

    public init(
        id: UUID = UUID(),
        type: TransactionType,
        categoryPath: String,
        iconName: String = "🍜",
        amount: Double,
        accountName: String = "TNGewallet",
        targetAccountName: String? = nil,
        ledgerName: String = "Main Ledger",
        note: String = "",
        counterparty: String = "",
        discountAmount: Double = 0.0,
        refundAmount: Double = 0.0,
        includeInStats: Bool = true,
        includeInBudget: Bool = true,
        receiptImageLabels: [String] = [],
        date: Date = Date(),
        isConfirmed: Bool = true
    ) {
        let resolvedCat = DefaultCatalog.resolveCategoryIds(from: categoryPath, type: type)
        let resolvedAcc = DefaultCatalog.resolveAccountId(from: accountName)
        let resolvedTarget = targetAccountName.flatMap { DefaultCatalog.resolveAccountId(from: $0) }
        self.init(
            id: id,
            ledgerId: ledgerName == "Main Ledger" ? "ledger_main" : ledgerName,
            type: type,
            amount: amount,
            currency: .myr,
            primaryCategoryId: resolvedCat.primaryId,
            subCategoryId: resolvedCat.subId,
            accountId: resolvedAcc,
            targetAccountId: resolvedTarget,
            note: note,
            counterparty: counterparty,
            discountAmount: discountAmount,
            refundAmount: refundAmount,
            includeInStats: includeInStats,
            includeInBudget: includeInBudget,
            tags: [],
            attachmentPaths: receiptImageLabels,
            date: date,
            createdAt: date,
            isConfirmed: isConfirmed,
            customIconOverride: iconName
        )
    }
}

public struct CategoryBudgetItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var categoryId: String
    public var categoryName: String
    public var iconName: String
    public var useFirstCharIcon: Bool
    public var monthlyLimit: Double
    public var sortOrder: Int

    public init(
        id: String,
        categoryId: String,
        categoryName: String,
        iconName: String,
        useFirstCharIcon: Bool = false,
        monthlyLimit: Double,
        sortOrder: Int
    ) {
        self.id = id
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.iconName = iconName
        self.useFirstCharIcon = useFirstCharIcon
        self.monthlyLimit = monthlyLimit
        self.sortOrder = sortOrder
    }
}

public struct LedgerItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var currency: CurrencyCode
    public var monthlyBudget: Double
    public var categoryBudgets: [CategoryBudgetItem]
    public var customDailyBudgets: [String: Double]

    public init(
        id: String,
        name: String,
        currency: CurrencyCode = .myr,
        monthlyBudget: Double = 3200.0,
        categoryBudgets: [CategoryBudgetItem] = [],
        customDailyBudgets: [String: Double] = [:]
    ) {
        self.id = id
        self.name = name
        self.currency = currency
        self.monthlyBudget = monthlyBudget
        self.categoryBudgets = categoryBudgets
        self.customDailyBudgets = customDailyBudgets
    }
}

public enum RecurringFrequency: String, Codable, CaseIterable, Sendable {
    case daily = "每天"
    case weekly = "每周"
    case monthly = "每月"
}

public struct ScheduledTransactionItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var type: TransactionType
    public var amount: Double
    public var categoryPath: String
    public var iconName: String
    public var accountName: String
    public var frequency: RecurringFrequency
    public var dayOfMonth: Int // 1..31
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        type: TransactionType = .expense,
        amount: Double,
        categoryPath: String,
        iconName: String = "🍜",
        accountName: String = "TNGewallet",
        frequency: RecurringFrequency = .monthly,
        dayOfMonth: Int = 1,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.amount = amount
        self.categoryPath = categoryPath
        self.iconName = iconName
        self.accountName = accountName
        self.frequency = frequency
        self.dayOfMonth = dayOfMonth
        self.isEnabled = isEnabled
    }
}
