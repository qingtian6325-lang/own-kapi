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

    public enum AccountEntryRoute: Equatable, Sendable, Identifiable {
        case expense(accountName: String)
        case transfer(accountName: String)

        public var id: String {
            switch self {
            case .expense(let name): return "expense:\(name)"
            case .transfer(let name): return "transfer:\(name)"
            }
        }

        public var accountName: String {
            switch self {
            case .expense(let name), .transfer(let name): return name
            }
        }

        public var transactionType: TransactionType {
            switch self {
            case .expense: return .expense
            case .transfer: return .transfer
            }
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
