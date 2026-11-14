import Foundation

/// Identifiable sheet route for 账户详情 「…」 → 编辑账户.
/// Prefer `sheet(item:)` over Bool + `if let` (blank white full-screen sheet).
public struct EditAccountSheetRoute: Identifiable, Equatable, Sendable {
    public let id: String

    public init(accountId: String) {
        self.id = accountId
    }
}

/// Pure navigation state for 资产 → 账户详情 → 记账/转账 sheets.
/// Keeps overlay dismiss, detail pop, and entry sheets from desyncing
/// (v1.3.10 symptom: left/right/left left the user stuck on 记账/home).
public struct AssetsAccountNavigationState: Equatable, Sendable {
    public var isAssetsPresented: Bool
    public var selectedAccountID: String?
    public var entryRoute: AccountEntryRoute?

    public init(
        isAssetsPresented: Bool = false,
        selectedAccountID: String? = nil,
        entryRoute: AccountEntryRoute? = nil
    ) {
        self.isAssetsPresented = isAssetsPresented
        self.selectedAccountID = selectedAccountID
        self.entryRoute = entryRoute
    }

    /// Each open gets a unique `presentationID` so `sheet(item:)` remounts and
    /// `RecordAndAISheetView` `@State selectedTab` initializes to the intended type
    /// (fixes flaky 转账 opening on 支出).
    public struct AccountEntryRoute: Equatable, Sendable, Identifiable {
        public let presentationID: UUID
        public let accountName: String
        public let transactionType: TransactionType

        /// Identity is the presentation UUID alone — `sheet(item:)` must not reuse
        /// a previous open even when account/tab match.
        public var id: UUID { presentationID }

        public init(
            transactionType: TransactionType,
            accountName: String,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.accountName = accountName
            self.transactionType = transactionType
        }

        public static func expense(accountName: String, presentationID: UUID = UUID()) -> AccountEntryRoute {
            AccountEntryRoute(transactionType: .expense, accountName: accountName, presentationID: presentationID)
        }

        public static func transfer(accountName: String, presentationID: UUID = UUID()) -> AccountEntryRoute {
            AccountEntryRoute(transactionType: .transfer, accountName: accountName, presentationID: presentationID)
        }
    }

    public enum Action: Equatable, Sendable {
        case presentAssets
        case openAccount(String)
        case openEntry(AccountEntryRoute)
        case dismissEntry
        /// Single back control: dismiss entry sheet → pop detail → dismiss assets overlay.
        case back
    }

    public struct Effect: Equatable, Sendable {
        public var dismissAssetsOverlay: Bool

        public init(dismissAssetsOverlay: Bool = false) {
            self.dismissAssetsOverlay = dismissAssetsOverlay
        }
    }

    @discardableResult
    public mutating func apply(_ action: Action) -> Effect {
        switch action {
        case .presentAssets:
            isAssetsPresented = true
            return Effect()

        case .openAccount(let id):
            selectedAccountID = id
            // Opening another account while a sheet is up would fight presentation.
            entryRoute = nil
            return Effect()

        case .openEntry(let route):
            // Never clear the account under an entry sheet — that pops detail
            // while the sheet is visible and leaves the user on 记账/home.
            entryRoute = route
            return Effect()

        case .dismissEntry:
            entryRoute = nil
            return Effect()

        case .back:
            if entryRoute != nil {
                entryRoute = nil
                return Effect()
            }
            if selectedAccountID != nil {
                selectedAccountID = nil
                return Effect()
            }
            if isAssetsPresented {
                isAssetsPresented = false
                return Effect(dismissAssetsOverlay: true)
            }
            return Effect()
        }
    }
}

/// Pure bootstrap for account-detail → 记账/转账 sheet tab.
/// Unit tests lock 记账→支出 and 转账→转账 without mounting SwiftUI.
public enum AccountEntrySheetBootstrap: Sendable {
    public static func intendedTab(
        for route: AssetsAccountNavigationState.AccountEntryRoute
    ) -> TransactionType {
        route.transactionType
    }

    /// 记账 → dismiss → 转账 must open transfer with a fresh presentation id.
    public static func tabAfterExpenseDismissThenTransfer(
        previousExpense: AssetsAccountNavigationState.AccountEntryRoute,
        nextTransfer: AssetsAccountNavigationState.AccountEntryRoute
    ) -> TransactionType {
        precondition(previousExpense.transactionType == .expense)
        precondition(nextTransfer.transactionType == .transfer)
        precondition(previousExpense.presentationID != nextTransfer.presentationID)
        return intendedTab(for: nextTransfer)
    }

    /// 转账 → dismiss → 记账 must open expense with a fresh presentation id.
    public static func tabAfterTransferDismissThenExpense(
        previousTransfer: AssetsAccountNavigationState.AccountEntryRoute,
        nextExpense: AssetsAccountNavigationState.AccountEntryRoute
    ) -> TransactionType {
        precondition(previousTransfer.transactionType == .transfer)
        precondition(nextExpense.transactionType == .expense)
        precondition(previousTransfer.presentationID != nextExpense.presentationID)
        return intendedTab(for: nextExpense)
    }
}
