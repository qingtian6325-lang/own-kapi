import Foundation

/// Display model for the account-detail 「初始余额」footer row.
public struct AccountInitialBalanceDisplay: Equatable, Sendable {
    public let title: String
    /// Live opening balance from account settings — never a hardcoded placeholder.
    public let amount: Double
    public let formattedAmount: String
    /// Account created / bookkeeping start date text when known; nil otherwise.
    public let startDateText: String?

    public init(title: String, amount: Double, formattedAmount: String, startDateText: String?) {
        self.title = title
        self.amount = amount
        self.formattedAmount = formattedAmount
        self.startDateText = startDateText
    }
}

/// Builds the 「初始余额」row from the account’s current `initialBalance` (and optional start date).
public enum AccountInitialBalanceRowBuilder {
    public static let title = "初始余额"

    public static func make(initialBalance: Double, startDate: Date?) -> AccountInitialBalanceDisplay {
        AccountInitialBalanceDisplay(
            title: title,
            amount: initialBalance,
            formattedAmount: MimiTheme.formatRM(initialBalance),
            startDateText: startDate.map { formatStartDate($0) }
        )
    }

    public static func make(from account: AccountItem, startDate: Date?) -> AccountInitialBalanceDisplay {
        make(initialBalance: account.initialBalance, startDate: startDate)
    }

    /// Prefer `account.createdAt`; else earliest 「设定期初资金」audit for that account.
    public static func resolveStartDate(for account: AccountItem, auditLogs: [AccountAuditLog]) -> Date? {
        if let created = account.createdAt {
            return created
        }
        let openingLogs = auditLogs.filter { log in
            (log.accountId == account.id || log.accountId == account.name)
                && log.categoryTitle.contains("设定期初资金")
        }
        return openingLogs.map(\.billDate).min()
    }

    public static func formatStartDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: date)
    }
}
