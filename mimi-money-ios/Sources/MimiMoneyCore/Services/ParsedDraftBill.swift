import Foundation

// 识别草稿的统一数据结构（原与旧 OCR 服务同文件，v1.2.1 移除 OCR 时独立成文件）。
public struct ParsedDraftBill: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var type: TransactionType
    public var amount: Double
    public var currency: CurrencyCode
    public var primaryCategoryId: String
    public var subCategoryId: String?
    public var categoryDisplayName: String
    public var accountId: String?
    public var accountDisplayName: String
    /// 转账对方账户（仅 type == .transfer 时有意义）
    public var targetAccountId: String?
    public var targetAccountDisplayName: String?
    public var merchantOrNote: String
    public var occurredAt: Date
    public var rawImageData: Data?

    public var categoryPath: String { categoryDisplayName }
    public var iconName: String {
        DefaultCatalog.resolveCategoryDisplay(
            primaryId: primaryCategoryId,
            subId: subCategoryId,
            type: type
        ).iconName
    }
    public var accountName: String { accountDisplayName }
    public var targetAccountName: String? { targetAccountDisplayName }
    public var note: String { merchantOrNote }
    public var date: Date { occurredAt }

    public init(
        id: UUID = UUID(),
        type: TransactionType = .expense,
        amount: Double,
        currency: CurrencyCode = .myr,
        primaryCategoryId: String,
        subCategoryId: String? = nil,
        categoryDisplayName: String,
        accountId: String? = nil,
        accountDisplayName: String,
        targetAccountId: String? = nil,
        targetAccountDisplayName: String? = nil,
        merchantOrNote: String,
        occurredAt: Date = Date(),
        rawImageData: Data? = nil
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.currency = currency
        self.primaryCategoryId = primaryCategoryId
        self.subCategoryId = subCategoryId
        self.categoryDisplayName = categoryDisplayName
        self.accountId = accountId
        self.accountDisplayName = accountDisplayName
        self.targetAccountId = targetAccountId
        self.targetAccountDisplayName = targetAccountDisplayName
        self.merchantOrNote = merchantOrNote
        self.occurredAt = occurredAt
        self.rawImageData = rawImageData
    }
}
