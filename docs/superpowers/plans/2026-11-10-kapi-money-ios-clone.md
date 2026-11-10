# Kapi Money (咔皮记账) iOS 1:1 Native Clone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 1:1 native SwiftUI iPhone clone of Kapi Money (咔皮记账) using `xtool` (`Package.swift` + `xtool.yml`), complete with all screens from `IMG_2240`–`IMG_2294`, dual-mode on-device + LLM AI bookkeeping, and the two-button (`修改 / View` & `确认 / Got it`) iOS Shortcuts screenshot bookkeeping flow.

**Architecture:** Pure native Swift 6 + SwiftUI application organized as a Swift Package Manager project (`kapi-money-ios/Package.swift` + `kapi-money-ios/xtool.yml`) with an separated testable core (`KapiMoneyCore` library target) and iOS app entry (`KapiMoneyApp` executable target). State and local persistence are managed by `@MainActor final class KapiStore: ObservableObject` backed by atomic JSON persistence in the app sandbox (shared directly with in-app `AppIntents` so free Apple ID signing works without paid `App Groups` or `CloudKit` entitlements).

**Tech Stack:** Swift 6.0, SwiftUI (iOS 16.0+), `AppIntents`, `Vision` (`VNRecognizeTextRequest`), `Speech`, `Charts`, `xtool` (`xtool.yml`), GitHub Actions (`macos-14` `.ipa` packaging + WSL2 `xtool dev` script).

**Spec:** `docs/superpowers/specs/2026-11-10-kapi-money-ios-clone-design.md`

## Global Constraints

- Target platform: iPhone iOS 16.0+ (`platforms: [.iOS(.v16), .macOS(.v13)]` in `Package.swift` so `swift test` runs on macOS/Linux host as well as iOS).
- Zero WebViews or HTML wrappers: 100% native SwiftUI views and components.
- Free Apple ID signing compatibility: In-app `AppIntents` sharing `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)` without requiring paid `CloudKit` or `App Groups` entitlements.
- Visual palette exact match: Background `#F5F6FA`, Card `#FFFFFF`, Expense Blue `#2D5AF0`, Income Orange `#E8832E`, Balance Green `#36B37E`.
- Default currency & accounts: `RM` (`MYR`), default ledger `Main Ledger`, preloaded accounts `现金` (`RM72.10`), `CIMB` (`RM23.45`), `TNGewallet` (`RM68.62`), `PBBank` (`RM204.25`).
- Full category hierarchy: 11 standard primary expense categories (66 secondary) + 2 custom expense (`家用`, `车贷`), and 8 standard primary income categories (20 secondary) + 1 custom income (`别人转账`), plus `"首字作为图标（包含emoji）"` toggle.

## Review Focus

1. **Calculator keypad chained expressions (`+` / `-`) in Manual Record Sheet:** Entering `"15.5+4.5-2"` before tapping `完成` or `再记` must evaluate to `18.00` instead of parsing as `NaN` or dropping operators, and negative/zero results must be guarded before saving.
2. **Transfer (`转账`) and non-income/expense (`不计入收支`) exclusion from monthly budget & stats:** Inter-account transfers (e.g. `TNGewallet -> PBBank RM100`) and bills marked `不计入收支` must update both account balances and account audit logs (`AccountAuditLog`), but must NOT inflate monthly expense totals (`月支出`), category pie charts, or reduce `今日可用` dynamic daily budget.
3. **Editing or deleting a historical transaction must accurately reconcile account balance & write an `AccountAuditLog` entry (`改` / `删`):** Changing a bill from `-RM5.90` on `TNGewallet` to `-RM8.30` on `PBBank` (or deleting it) must refund `RM5.90` to `TNGewallet`, deduct `RM8.30` from `PBBank`, and record a `改` or `删` (strikethrough amount) audit entry with the exact post-operation snapshot balance (`余额: RMxx.xx`).
4. **Dynamic daily budget division on the last day of the month or when overspent:** When `S_past >= B_month` (monthly budget already exceeded), `DailyBudget` must clamp to `0.00` (never negative), and on the last day of the month (`D_remain == 1`) it must never divide by zero.
5. **TNG eWallet / bank screenshot OCR noise resilience:** Real payment screenshots (`IMG_2294`) contain reference numbers (`2026110810110000010000TNGOW3MY17129...`) and timestamps (`08/11/2026 16:56:34`); the OCR parser must extract the actual currency amount (`RM5.90`) rather than mistaking the 20-digit reference number or date digits for the transaction amount.

---

### Task 1: `xtool` + SwiftPM Scaffolding, Theme Tokens & Full Category/Account Domain Models

**Files:**
- Modify: `.gitignore`
- Create: `kapi-money-ios/Package.swift`
- Create: `kapi-money-ios/xtool.yml`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Theme/KapiTheme.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Models/KapiModels.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Models/DefaultCatalog.swift`
- Create: `kapi-money-ios/Tests/KapiMoneyTests/ModelAndCatalogTests.swift`
- Create: `kapi-money-ios/scripts/verify-swift-project.mjs`

**Interfaces:**
- Consumes: none (foundational task)
- Produces:
  - `public enum CurrencyCode: String, CaseIterable, Codable, Sendable` (`.myr`, `.cny`, `.usd`, `.sgd`, with `symbol: String` where `.myr` is `"RM"`)
  - `public enum TransactionType: String, CaseIterable, Codable, Sendable` (`.expense`, `.income`, `.transfer`)
  - `public struct SubCategory: Identifiable, Codable, Equatable, Sendable` (`id`, `name`, `iconName`, `useFirstCharIcon`, `sortOrder`)
  - `public struct CategoryGroup: Identifiable, Codable, Equatable, Sendable` (`id`, `name`, `type: TransactionType`, `iconName`, `useFirstCharIcon`, `isCustom: Bool`, `subCategories: [SubCategory]`, `sortOrder`)
  - `public struct AccountItem: Identifiable, Codable, Equatable, Sendable` (`id`, `name`, `subtitle`, `badgeText: String?`, `iconName`, `balance: Double`, `isLiability: Bool`)
  - `public enum AuditActionType: String, Codable, Sendable` (`.created` = `"记"`, `.updated` = `"改"`, `.deleted` = `"删"`)
  - `public struct AccountAuditLog: Identifiable, Codable, Equatable, Sendable` (`id`, `accountId`, `action: AuditActionType`, `transactionType: TransactionType`, `categoryTitle: String`, `note: String`, `amount: Double`, `balanceAfter: Double`, `billDate: Date`, `loggedAt: Date`)
  - `public struct TransactionItem: Identifiable, Codable, Equatable, Sendable` (`id`, `ledgerId`, `type: TransactionType`, `amount: Double`, `currency: CurrencyCode`, `primaryCategoryId: String`, `subCategoryId: String?`, `accountId: String?`, `targetAccountId: String?`, `note: String`, `counterparty: String`, `discountAmount: Double`, `refundAmount: Double`, `includeInStats: Bool`, `tags: [String]`, `attachmentPaths: [String]`, `date: Date`, `createdAt: Date`)
  - `public struct CategoryBudgetItem: Identifiable, Codable, Equatable, Sendable` (`id`, `categoryId`, `categoryName`, `iconName`, `monthlyLimit: Double`, `sortOrder: Int`)
  - `public struct LedgerItem: Identifiable, Codable, Equatable, Sendable` (`id`, `name`, `currency: CurrencyCode`, `monthlyBudget: Double`, `categoryBudgets: [CategoryBudgetItem]`, `customDailyBudgets: [String: Double]`)
  - `public enum DefaultCatalog` (`standardExpenseCategories() -> [CategoryGroup]`, `standardIncomeCategories() -> [CategoryGroup]`, `defaultAccounts() -> [AccountItem]`, `defaultLedger() -> LedgerItem`, `stickerIconLibrary() -> [String]`)

- [ ] **Step 1: Write the failing test in `kapi-money-ios/Tests/KapiMoneyTests/ModelAndCatalogTests.swift` and verification runner `kapi-money-ios/scripts/verify-swift-project.mjs`**

```swift
import XCTest
@testable import KapiMoneyCore

final class ModelAndCatalogTests: XCTestCase {
    func testExpenseAndIncomeCatalogExactCounts() {
        let expenses = DefaultCatalog.standardExpenseCategories()
        // 13 standard primary (11 with/without subs: 餐饮7, 购物7, 交通7, 住房6, 休闲娱乐6, 医疗健康5, 学习办公4, 宠物4, 母婴3, 资金往来2, 保险0, 投资理财0, 其他支出0) + 2 custom (家用, 车贷) = 15 groups
        XCTAssertEqual(expenses.count, 15)
        let totalExpenseSubs = expenses.reduce(0) { $0 + $1.subCategories.count }
        XCTAssertEqual(totalExpenseSubs, 51) // exact subcategories shown in IMG_2247, IMG_2248, IMG_2267-2282
        XCTAssertTrue(expenses.contains(where: { $0.name == "家用" && $0.isCustom }))
        XCTAssertTrue(expenses.contains(where: { $0.name == "车贷" && $0.isCustom }))

        let incomes = DefaultCatalog.standardIncomeCategories()
        XCTAssertEqual(incomes.count, 9) // 8 standard + 别人转账
        XCTAssertTrue(incomes.contains(where: { $0.name == "别人转账" && $0.isCustom }))
    }

    func testDefaultAccountsMatchScreenshots() {
        let accounts = DefaultCatalog.defaultAccounts()
        XCTAssertEqual(accounts.map(\.name), ["现金", "CIMB", "TNGewallet", "PBBank"])
        let totalNetWorth = accounts.reduce(0.0) { $0 + $1.balance }
        XCTAssertEqual(totalNetWorth, 368.42, accuracy: 0.001)
    }

    func testFirstCharIconDisplayExtraction() {
        let cat = CategoryGroup(
            id: "custom_piano",
            name: "琴房学费",
            type: .expense,
            iconName: "music.note",
            useFirstCharIcon: true,
            isCustom: true,
            subCategories: [],
            sortOrder: 99
        )
        XCTAssertEqual(cat.displayBadgeToken, "琴")
    }
}
```

- [ ] **Step 2: Run verification to confirm it fails before implementation**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 1`
Expected: FAIL with missing `kapi-money-ios/Package.swift` and `DefaultCatalog.swift`.

- [ ] **Step 3: Implement `.gitignore`, `Package.swift`, `xtool.yml`, `KapiTheme.swift`, `KapiModels.swift`, and `DefaultCatalog.swift`**

Add `.superpowers/` to `.gitignore`. Configure `kapi-money-ios/xtool.yml` (`version: 1`, `bundleID: com.jinghao.kapimoney`, `product: KapiMoneyApp`) and `kapi-money-ios/Package.swift` with `KapiMoneyCore`, `KapiMoneyApp`, and `KapiMoneyTests`. Populate `DefaultCatalog.swift` with every primary and secondary category from `IMG_2247`, `IMG_2248`, and `IMG_2267`–`IMG_2282`, plus the 4 accounts (`现金: 72.10`, `CIMB: 23.45`, `TNGewallet: 68.62`, `PBBank: 204.25` summing to `RM368.42`) and initial transactions matching `IMG_2240`–`IMG_2262`.

- [ ] **Step 4: Run verification to confirm Task 1 passes**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 1`
Expected: PASS (`Task 1 verified: Package.swift, xtool.yml, KapiTheme, KapiModels, DefaultCatalog all valid`).

- [ ] **Step 5: Commit**

```bash
git add .gitignore kapi-money-ios/Package.swift kapi-money-ios/xtool.yml kapi-money-ios/Sources/KapiMoneyCore/Theme/KapiTheme.swift kapi-money-ios/Sources/KapiMoneyCore/Models/KapiModels.swift kapi-money-ios/Sources/KapiMoneyCore/Models/DefaultCatalog.swift kapi-money-ios/Tests/KapiMoneyTests/ModelAndCatalogTests.swift kapi-money-ios/scripts/verify-swift-project.mjs
git commit -m "feat(ios): scaffold xtool SwiftPM project and Kapi Money catalog models"
```

---

### Task 2: Local Persistence Store, Account Audit Log (`记`/`改`/`删`), Calculator Evaluator & Dynamic Daily Budget Engine

**Files:**
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Services/KeypadCalculator.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Services/DynamicBudgetEngine.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Services/KapiStore.swift`
- Create: `kapi-money-ios/Tests/KapiMoneyTests/StoreAndBudgetTests.swift`
- Modify: `kapi-money-ios/scripts/verify-swift-project.mjs`

**Interfaces:**
- Consumes: Task 1 models (`TransactionItem`, `AccountItem`, `AccountAuditLog`, `LedgerItem`, `CategoryGroup`, `DefaultCatalog`)
- Produces:
  - `public enum KeypadCalculator` (`public static func evaluate(_ expression: String) -> Double`)
  - `public enum DynamicBudgetEngine`:
    - `public static func calculateDailyBudget(monthlyBudget: Double, spentBeforeToday: Double, remainingDaysIncludingToday: Int) -> Double`
    - `public static func buildMonthDayCells(year: Int, month: Int, today: Date, ledger: LedgerItem, transactions: [TransactionItem]) -> [DailyBudgetCellModel]`
  - `@MainActor public final class KapiStore: ObservableObject`:
    - `@Published public var ledgers: [LedgerItem]`
    - `@Published public var currentLedgerId: String`
    - `@Published public var accounts: [AccountItem]`
    - `@Published public var transactions: [TransactionItem]`
    - `@Published public var auditLogs: [AccountAuditLog]`
    - `@Published public var expenseCategories: [CategoryGroup]`
    - `@Published public var incomeCategories: [CategoryGroup]`
    - `@Published public var pendingEditTransactionId: UUID?`
    - `public func addTransaction(_ item: TransactionItem, at loggedAt: Date = Date())`
    - `public func updateTransaction(_ updated: TransactionItem, at loggedAt: Date = Date())`
    - `public func deleteTransaction(id: UUID, at loggedAt: Date = Date())`
    - `public func updateAccountBalance(accountId: String, newBalance: Double)`
    - `public func resetToDemoData()`
    - `public func clearAllDemoTransactions()`

- [ ] **Step 1: Write the failing tests in `kapi-money-ios/Tests/KapiMoneyTests/StoreAndBudgetTests.swift`**

```swift
import XCTest
@testable import KapiMoneyCore

@MainActor
final class StoreAndBudgetTests: XCTestCase {
    func testCalculatorChainedExpressionEvaluation() {
        XCTAssertEqual(KeypadCalculator.evaluate("15.5+4.5-2"), 18.0, accuracy: 0.001)
        XCTAssertEqual(KeypadCalculator.evaluate("10-25"), 0.0, accuracy: 0.001) // clamped non-negative
        XCTAssertEqual(KeypadCalculator.evaluate("38.78+"), 38.78, accuracy: 0.001)
    }

    func testDynamicDailyBudgetFormulaAndEdgeCases() {
        // IMG_2240: Monthly budget RM3,200.00, spent RM1,262.52 before Nov 10, 21 days remaining (Nov 10..30) -> 1937.48 / 21 = 92.26
        let daily = DynamicBudgetEngine.calculateDailyBudget(
            monthlyBudget: 3200.00,
            spentBeforeToday: 1262.52,
            remainingDaysIncludingToday: 21
        )
        XCTAssertEqual(daily, 92.26, accuracy: 0.01)

        // Review Focus #4: Overspent & last day edge cases
        XCTAssertEqual(
            DynamicBudgetEngine.calculateDailyBudget(monthlyBudget: 3200, spentBeforeToday: 3500, remainingDaysIncludingToday: 5),
            0.0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            DynamicBudgetEngine.calculateDailyBudget(monthlyBudget: 3200, spentBeforeToday: 3100, remainingDaysIncludingToday: 0),
            100.0,
            accuracy: 0.001
        )
    }

    func testAccountBalanceReconciliationAndAuditLogsOnCreateEditDelete() {
        let store = KapiStore(inMemory: true)
        let tngId = "acc_tng"
        let pbbId = "acc_pbb"
        let initialTng = store.accounts.first(where: { $0.id == tngId })!.balance

        // 1. Add expense RM5.90 on TNGewallet -> writes "记" audit log
        let tx = TransactionItem(
            ledgerId: store.currentLedgerId,
            type: .expense,
            amount: 5.90,
            currency: .myr,
            primaryCategoryId: "exp_food",
            subCategoryId: "exp_food_snack",
            accountId: tngId,
            note: "Near Me Voucher Eggette Lab 消费"
        )
        store.addTransaction(tx)
        XCTAssertEqual(store.accounts.first(where: { $0.id == tngId })!.balance, initialTng - 5.90, accuracy: 0.001)
        XCTAssertEqual(store.auditLogs.first?.action, .created)

        // 2. Edit transaction to RM8.30 on PBBank -> refunds TNGewallet, deducts PBBank, writes "改" audit log
        var edited = tx
        edited.amount = 8.30
        edited.accountId = pbbId
        store.updateTransaction(edited)
        XCTAssertEqual(store.accounts.first(where: { $0.id == tngId })!.balance, initialTng, accuracy: 0.001)
        XCTAssertEqual(store.auditLogs.first?.action, .updated)

        // 3. Delete transaction -> refunds PBBank, writes "删" audit log
        store.deleteTransaction(id: tx.id)
        XCTAssertEqual(store.auditLogs.first?.action, .deleted)
    }

    func testTransferAndExcludeFromStatsDoNotAffectMonthlyExpense() {
        let store = KapiStore(inMemory: true)
        let beforeExpense = store.monthlyExpenseTotal(year: 2026, month: 11)
        let transfer = TransactionItem(
            ledgerId: store.currentLedgerId,
            type: .transfer,
            amount: 100.0,
            currency: .myr,
            primaryCategoryId: "transfer",
            accountId: "acc_tng",
            targetAccountId: "acc_pbb",
            note: "转账RM100"
        )
        store.addTransaction(transfer)
        XCTAssertEqual(store.monthlyExpenseTotal(year: 2026, month: 11), beforeExpense, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run verification to confirm Task 2 fails**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 2`
Expected: FAIL with missing `KeypadCalculator.swift`, `DynamicBudgetEngine.swift`, and `KapiStore.swift`.

- [ ] **Step 3: Implement `KeypadCalculator.swift`, `DynamicBudgetEngine.swift`, and `KapiStore.swift`**

Implement safe left-to-right `+`/`-` expression evaluation in `KeypadCalculator.evaluate(_:)`. Implement `DynamicBudgetEngine.calculateDailyBudget` using $\max(0, (B_{\text{month}} - S_{\text{past}}) / \max(1, D_{\text{remain}}))$. Implement `KapiStore` with JSON persistence in `Documents/kapi_money_state.json`, balance adjustments for `.expense`, `.income`, and `.transfer`, automatic `AccountAuditLog` generation (`记`/`改`/`删`), and CSV/JSON export/import strings.

- [ ] **Step 4: Run verification to confirm Task 2 passes**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 2`
Expected: PASS (`Task 2 verified: KeypadCalculator, DynamicBudgetEngine, and KapiStore audit & balance logic valid`).

- [ ] **Step 5: Commit**

```bash
git add kapi-money-ios/Sources/KapiMoneyCore/Services/KeypadCalculator.swift kapi-money-ios/Sources/KapiMoneyCore/Services/DynamicBudgetEngine.swift kapi-money-ios/Sources/KapiMoneyCore/Services/KapiStore.swift kapi-money-ios/Tests/KapiMoneyTests/StoreAndBudgetTests.swift kapi-money-ios/scripts/verify-swift-project.mjs
git commit -m "feat(ios): implement KapiStore persistence, account audit log, and dynamic daily budget engine"
```

---

### Task 3: Dual-Mode AI Bookkeeping Parser, Vision Receipt OCR & CFO Query Engine

**Files:**
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Services/ReceiptOCRService.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Services/KapiAIEngine.swift`
- Create: `kapi-money-ios/Tests/KapiMoneyTests/AIEngineAndOCRTests.swift`
- Modify: `kapi-money-ios/scripts/verify-swift-project.mjs`

**Interfaces:**
- Consumes: Task 1 & Task 2 models and `KapiStore`
- Produces:
  - `public struct ParsedDraftBill: Identifiable, Codable, Equatable, Sendable` (`id`, `type: TransactionType`, `amount: Double`, `currency: CurrencyCode`, `primaryCategoryId: String`, `subCategoryId: String?`, `categoryDisplayName: String`, `accountId: String?`, `accountDisplayName: String`, `merchantOrNote: String`, `occurredAt: Date`)
  - `public enum AIChatResponseBlock: Equatable, Sendable` (`.text(String)`, `.draftBills([ParsedDraftBill])`, `.categoryTable(expenseRows: [(String, String)], incomeRows: [(String, String)], customNote: String)`, `.spendingSummary(title: String, amount: Double, count: Int, details: String)`)
  - `public final class ReceiptOCRService: Sendable`:
    - `public static func parseReceiptText(_ rawText: String, now: Date = Date()) -> ParsedDraftBill`
    - `public static func recognizeAndParseImageData(_ data: Data, now: Date = Date()) async -> ParsedDraftBill`
  - `@MainActor public final class KapiAIEngine: ObservableObject`:
    - `public func parseNaturalLanguageBills(_ input: String, now: Date = Date()) -> [ParsedDraftBill]`
    - `public func handleUserMessage(_ message: String, in store: KapiStore) async -> [AIChatResponseBlock]`

- [ ] **Step 1: Write the failing tests in `kapi-money-ios/Tests/KapiMoneyTests/AIEngineAndOCRTests.swift`**

```swift
import XCTest
@testable import KapiMoneyCore

@MainActor
final class AIEngineAndOCRTests: XCTestCase {
    func testParseTNGeWalletScreenshotTextIgnoresWalletRefNumbers() {
        // Review Focus #5: Exact OCR text from IMG_2294.PNG
        let rawOCR = """
        -RM5.90
        Near Me Voucher Eggette Lab
        Payment Details Payment - TNGD
        Payment Method eWallet Balance
        Date/Time 08/11/2026 16:56:34
        Wallet Ref 2026110810110000010000TNGOW3MY171298463015729
        Status Successful
        Transaction No. 202611081656326680004726107380
        """
        let draft = ReceiptOCRService.parseReceiptText(rawOCR)
        XCTAssertEqual(draft.amount, 5.90, accuracy: 0.001)
        XCTAssertEqual(draft.accountDisplayName, "TNGewallet")
        XCTAssertEqual(draft.categoryDisplayName, "餐饮-零食甜品")
        XCTAssertTrue(draft.merchantOrNote.contains("Near Me Voucher"))
    }

    func testMultiBillNaturalLanguageSentenceSplitting() {
        let engine = KapiAIEngine()
        let bills = engine.parseNaturalLanguageBills("中午吃餐厅花了8.30，TNG打麻将输钱28，PBBank加油38.78")
        XCTAssertEqual(bills.count, 3)
        XCTAssertEqual(bills[0].amount, 8.30, accuracy: 0.001)
        XCTAssertEqual(bills[1].amount, 28.00, accuracy: 0.001)
        XCTAssertEqual(bills[1].accountDisplayName, "TNGewallet")
        XCTAssertEqual(bills[2].amount, 38.78, accuracy: 0.001)
        XCTAssertEqual(bills[2].accountDisplayName, "PBBank")
    }

    func testCategoryQuestionReturnsStandardCategoryTable() async {
        // Matches IMG_2246, IMG_2247, IMG_2248
        let store = KapiStore(inMemory: true)
        let engine = KapiAIEngine()
        let blocks = await engine.handleUserMessage("可以增加或删除某个分类吗？", in: store)
        XCTAssertTrue(blocks.contains(where: {
            if case .categoryTable = $0 { return true }
            return false
        }))
    }
}
```

- [ ] **Step 2: Run verification to confirm Task 3 fails**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 3`
Expected: FAIL with missing `ReceiptOCRService.swift` and `KapiAIEngine.swift`.

- [ ] **Step 3: Implement `ReceiptOCRService.swift` and `KapiAIEngine.swift`**

In `ReceiptOCRService.parseReceiptText(_:now:)`, strip 12+ digit reference/transaction numbers before amount matching, prioritize currency-prefixed tokens (`RM`, `MYR`, `¥`, `$`) or decimal amounts (`\d+\.\d{2}`), detect payment method keywords (`TNGD`/`eWallet`/`Touch 'n Go` -> `TNGewallet`, `PBBank`/`Public Bank` -> `PBBank`, `CIMB` -> `CIMB`), and map merchant keywords to `DefaultCatalog` subcategories. In `KapiAIEngine`, split multi-clause sentences on `，|,|；|;|和|还有|\n`, parse each clause into `ParsedDraftBill`, answer category/VIP/shared-ledger/spending queries locally (matching `IMG_2246`–`IMG_2248`), and support optional OpenAI-compatible API key configuration in `UserDefaults`.

- [ ] **Step 4: Run verification to confirm Task 3 passes**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 3`
Expected: PASS (`Task 3 verified: ReceiptOCRService and KapiAIEngine tests valid`).

- [ ] **Step 5: Commit**

```bash
git add kapi-money-ios/Sources/KapiMoneyCore/Services/ReceiptOCRService.swift kapi-money-ios/Sources/KapiMoneyCore/Services/KapiAIEngine.swift kapi-money-ios/Tests/KapiMoneyTests/AIEngineAndOCRTests.swift kapi-money-ios/scripts/verify-swift-project.mjs
git commit -m "feat(ios): add Vision receipt OCR parser and dual-mode AI bookkeeping engine"
```

---

### Task 4: iOS Shortcuts (`AppIntents`) Screenshot Bookkeeping & Two-Button (`修改/View` & `确认/Got it`) Flow

**Files:**
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Intents/KapiShortcuts.swift`
- Create: `kapi-money-ios/Tests/KapiMoneyTests/ShortcutIntentTests.swift`
- Modify: `kapi-money-ios/scripts/verify-swift-project.mjs`

**Interfaces:**
- Consumes: Task 2 `KapiStore` & Task 3 `ReceiptOCRService`, `ParsedDraftBill`
- Produces:
  - `public struct ShortcutExecutionOutcome: Equatable, Sendable` (`transactionId: UUID`, `draft: ParsedDraftBill`, `didOpenAppForEditing: Bool`)
  - `@MainActor public enum ShortcutActionCoordinator`:
    - `public static func recordRecognizedDraft(_ draft: ParsedDraftBill, in store: KapiStore) -> TransactionItem`
    - `public static func markForInAppModification(transactionId: UUID, in store: KapiStore) -> URL`
    - `public static func handleIncomingURL(_ url: URL, in store: KapiStore) -> Bool`
  - `AppIntents` structures (`ScanScreenshotIntent`, `OpenBillForEditIntent`, `ConfirmBillIntent`, `KapiAppShortcutsProvider`, and `ScreenshotResultSnippetView` matching `IMG_2294.PNG`)

- [ ] **Step 1: Write the failing tests in `kapi-money-ios/Tests/KapiMoneyTests/ShortcutIntentTests.swift`**

```swift
import XCTest
@testable import KapiMoneyCore

@MainActor
final class ShortcutIntentTests: XCTestCase {
    func testShortcutRecognizeAndConfirmSavesDirectly() {
        let store = KapiStore(inMemory: true)
        let initialCount = store.transactions.count
        let draft = ReceiptOCRService.parseReceiptText("-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34")
        let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
        XCTAssertEqual(store.transactions.count, initialCount + 1)
        XCTAssertEqual(saved.amount, 5.90, accuracy: 0.001)
        XCTAssertNil(store.pendingEditTransactionId)
    }

    func testShortcutModifyButtonDeepLinksIntoAppBillEditor() {
        let store = KapiStore(inMemory: true)
        let draft = ReceiptOCRService.parseReceiptText("-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab")
        let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
        let url = ShortcutActionCoordinator.markForInAppModification(transactionId: saved.id, in: store)
        XCTAssertEqual(url.absoluteString, "kapimoney://edit-bill?id=\(saved.id.uuidString)")

        store.pendingEditTransactionId = nil
        let handled = ShortcutActionCoordinator.handleIncomingURL(url, in: store)
        XCTAssertTrue(handled)
        XCTAssertEqual(store.pendingEditTransactionId, saved.id)
    }
}
```

- [ ] **Step 2: Run verification to confirm Task 4 fails**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 4`
Expected: FAIL with missing `KapiShortcuts.swift`.

- [ ] **Step 3: Implement `KapiShortcuts.swift` with `AppIntents` and `ScreenshotResultSnippetView`**

Implement `ShortcutActionCoordinator` and the `AppIntents` structs (`ScanScreenshotIntent`, `OpenBillForEditIntent` with `openAppWhenRun = true`, `ConfirmBillIntent`, and `KapiAppShortcutsProvider`). Build `ScreenshotResultSnippetView` matching `IMG_2294.PNG` (blue-white gradient header, white inner card with snack icon, `餐饮-零食甜品`, `-RM5.90` in `#2D5AF0`, gray pills for `TNGewallet` and merchant, timestamp, `✔ 已识别记录以上信息，打开「咔皮记账」查看更多`, and the two pill buttons: left gray `修改 (View)` triggering `OpenBillForEditIntent` / `kapimoney://edit-bill?id=...` and right blue `确认 (Got it)` triggering `ConfirmBillIntent`).

- [ ] **Step 4: Run verification to confirm Task 4 passes**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 4`
Expected: PASS (`Task 4 verified: ShortcutActionCoordinator, AppIntents, and DeepLink routing valid`).

- [ ] **Step 5: Commit**

```bash
git add kapi-money-ios/Sources/KapiMoneyCore/Intents/KapiShortcuts.swift kapi-money-ios/Tests/KapiMoneyTests/ShortcutIntentTests.swift kapi-money-ios/scripts/verify-swift-project.mjs
git commit -m "feat(ios): implement AppIntents screenshot recognition popup with View/Modify and Got-it buttons"
```

---

### Task 5: Sticker Icon Component, Home Screen (`记录`), Side Drawer (`IMG_2249`), and All-Records Heatmap Calendar (`IMG_2250`–`2252`)

**Files:**
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Components/KapiStickerIconView.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Views/HomeRecordView.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Views/SideDrawerMenuView.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Views/AllRecordsCalendarView.swift`
- Modify: `kapi-money-ios/scripts/verify-swift-project.mjs`

**Interfaces:**
- Consumes: `KapiStore`, `KapiTheme`, `DynamicBudgetEngine`, `CategoryGroup`, `SubCategory`
- Produces:
  - `public struct KapiStickerIconView: View` (renders hand-drawn style circular sticker badge or blue/orange first-character/emoji badge when `useFirstCharIcon == true`)
  - `public struct HomeRecordView: View` (exact match for `IMG_2240` & `IMG_2241`)
  - `public struct SideDrawerMenuView: View` (exact match for `IMG_2249` with `November 2026` check-in grid, `29 记录天数 / 141 总记录 / 1 连续天数`, 7-grid `更多功能`, and 3-grid `快捷记账`)
  - `public struct AllRecordsCalendarView: View` (exact match for `IMG_2250`, `IMG_2251`, `IMG_2252`, `IMG_2265` with `收支/支出` filter, `回今天` pill, orange-to-blue heatmap cells, crown icon on highest expense day, and selected-day bill list)

- [ ] **Step 1: Add Task 5 view & component structural/state assertions to `kapi-money-ios/scripts/verify-swift-project.mjs`**

Verify `KapiStickerIconView.swift`, `HomeRecordView.swift`, `SideDrawerMenuView.swift`, and `AllRecordsCalendarView.swift` contain all required UI labels and bindings from `IMG_2240`–`IMG_2241` (`月预算剩余`, `今日可用`, `分类预算`, `净资产`, `30天趋势`, `记录明细`, `任何事情都能问我`), `IMG_2249` (`记录天数`, `总记录`, `连续天数`, `图表统计`, `资产管理`, `账本管理`, `预算管理`, `小组件`, `分类管理`, `标签管理`, `导入导出`, `自动记账`, `定时记账`), and `IMG_2250`–`IMG_2252` (`全部记录`, `回今天`, `收支分析`, `收入多`, `支出多`).

- [ ] **Step 2: Run verification to confirm Task 5 fails**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 5`
Expected: FAIL with missing Task 5 view files.

- [ ] **Step 3: Implement `KapiStickerIconView.swift`, `HomeRecordView.swift`, `SideDrawerMenuView.swift`, and `AllRecordsCalendarView.swift`**

Build `KapiStickerIconView` with custom multi-tone illustration badges + first-character mode (`IMG_2293`). Build `HomeRecordView` with top bar (`☰ 记录 ⌄`, search button, `Main Ledger ⌄`), monthly budget card with eye toggle, progress bar (`39%`), multi-segment ring chart (`今日可用 92.26`), expandable `分类预算 共6项`, collapsible light-blue net worth card (`净资产 RM368.42` + 30-day trend sparkline), daily grouped transaction list (`11月8日 (周日)` / `11月7日 (周六)`), and floating bottom bar (`🦫 任何事情都能问我` + `+`). Build `SideDrawerMenuView` and `AllRecordsCalendarView`.

- [ ] **Step 4: Run verification to confirm Task 5 passes**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 5`
Expected: PASS (`Task 5 verified: Home, SideDrawer, StickerIcon, and AllRecordsCalendar views complete`).

- [ ] **Step 5: Commit**

```bash
git add kapi-money-ios/Sources/KapiMoneyCore/Components/KapiStickerIconView.swift kapi-money-ios/Sources/KapiMoneyCore/Views/HomeRecordView.swift kapi-money-ios/Sources/KapiMoneyCore/Views/SideDrawerMenuView.swift kapi-money-ios/Sources/KapiMoneyCore/Views/AllRecordsCalendarView.swift kapi-money-ios/scripts/verify-swift-project.mjs
git commit -m "feat(ios): build HomeRecordView, SideDrawerMenuView, StickerIconView, and AllRecordsCalendarView"
```

---

### Task 6: Dual-Mode Record Sheet (`手动记账 ⇄ AI助手`), Calculator Keypad, and Bill Detail / Edit Sheet (`IMG_2242`–`2248`)

**Files:**
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Views/RecordAndAISheetView.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Views/BillDetailSheetView.swift`
- Modify: `kapi-money-ios/scripts/verify-swift-project.mjs`

**Interfaces:**
- Consumes: `KapiStore`, `KeypadCalculator`, `KapiAIEngine`, `ReceiptOCRService`, `KapiStickerIconView`
- Produces:
  - `public struct RecordAndAISheetView: View` (exact match for `IMG_2245`–`IMG_2248` with `⇄ AI助手` / `⇄ 手动记账` toggle, `支出 | 收入 | 转账`, category & subcategory grid, metadata pills, `RM0.00 MYR ⌄`, note & photo/camera picker, custom calculator keypad with `再记` & `完成`, and AI assistant chat with preset chips, category tables, and screenshot/natural-language bill cards)
  - `public struct BillDetailSheetView: View` (exact match for `IMG_2242` & `IMG_2243` with `账单详情`, trash delete button, `实付金额`, `分类`, `备注` + receipt image thumbnails + `+` button, `账单时间`, `付款账户`, `所属账本`, `添加优惠`, `添加退款/返现`, and `交易方`)

- [ ] **Step 1: Add Task 6 assertions to `kapi-money-ios/scripts/verify-swift-project.mjs`**

Verify `RecordAndAISheetView.swift` and `BillDetailSheetView.swift` implement all fields and actions from `IMG_2242`–`IMG_2248`.

- [ ] **Step 2: Run verification to confirm Task 6 fails**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 6`
Expected: FAIL with missing `RecordAndAISheetView.swift` and `BillDetailSheetView.swift`.

- [ ] **Step 3: Implement `RecordAndAISheetView.swift` and `BillDetailSheetView.swift`**

Implement the mode-switching bottom sheet (`手动记账` vs `任何事都能问我` AI mode) and the `账单详情` sheet (`IMG_2242`–`IMG_2243`) with inline editing for amount, 2-level category, note, receipt attachment thumbnails, date/time, payment account, ledger, discount (`添加优惠`), refund/cashback (`添加退款/返现`), counterparty (`交易方`), and deletion.

- [ ] **Step 4: Run verification to confirm Task 6 passes**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 6`
Expected: PASS (`Task 6 verified: RecordAndAISheetView and BillDetailSheetView complete`).

- [ ] **Step 5: Commit**

```bash
git add kapi-money-ios/Sources/KapiMoneyCore/Views/RecordAndAISheetView.swift kapi-money-ios/Sources/KapiMoneyCore/Views/BillDetailSheetView.swift kapi-money-ios/scripts/verify-swift-project.mjs
git commit -m "feat(ios): implement dual-mode RecordAndAISheetView and BillDetailSheetView"
```

---

### Task 7: `Kapi` Stats (`IMG_2253`–`2257`), Assets & Audit Detail (`IMG_2258`–`2262`), Budget Management (`IMG_2263`–`2266`), Category Manager (`IMG_2267`–`2293`), App Root & Build Workflows

**Files:**
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Views/KapiStatsView.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Views/AssetsAndAccountDetailView.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Views/BudgetManagementView.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Views/CategoryManagementView.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Views/SettingsAndShortcutsGuideView.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyCore/Views/KapiRootContainerView.swift`
- Create: `kapi-money-ios/Sources/KapiMoneyApp/KapiMoneyApp.swift`
- Create: `kapi-money-ios/scripts/build-wsl-xtool.sh`
- Create: `.github/workflows/build-kapi-ios.yml`
- Modify: `kapi-money-ios/scripts/verify-swift-project.mjs`

**Interfaces:**
- Consumes: All earlier tasks (`KapiStore`, `DynamicBudgetEngine`, `ReceiptOCRService`, `KapiAIEngine`, `ShortcutActionCoordinator`, and views from Tasks 5–6)
- Produces:
  - `public struct KapiStatsView: View` (`IMG_2253`–`IMG_2257`: `周 | 月 | 年 | 自定义`, Capybara wealth banner `本周结余 RM41.19`, donut chart `支出分类构成`, bar chart `每日支出趋势`, Top 10 `单笔支出排行`, and tabular `账单汇总`)
  - `public struct AssetsAndAccountDetailView: View` (`IMG_2258`–`IMG_2262`: `净资产 RM368.42`, `待报销 RM1000.00`, account cards, and `账户详情` with `📅 明细` [`记`/`改`/`删` + `余额: RM68.62`] vs `🧾 账单` toggle)
  - `public struct BudgetManagementView: View` (`IMG_2263`–`IMG_2266`: `已分类预算`, `未分类预算`, and `动态日预算` calendar with long-press daily budget override)
  - `public struct CategoryManagementView: View` (`IMG_2267`–`IMG_2293`: `分类方案管理`, subcategory bottom sheet, and `添加1级支出分类` with `首字作为图标（包含emoji）` toggle + 100+ sticker icon grid)
  - `public struct SettingsAndShortcutsGuideView: View` (AI API Key settings, interactive `IMG_2294` Shortcut simulator/tester right inside the app, ledger/tag/recurring bill management, CSV/JSON import/export, and demo data reset)
  - `public struct KapiRootContainerView: View` & `@main struct KapiMoneyApp: App` (handles `onOpenURL` deep linking from the Shortcut `修改 / View` button straight into `BillDetailSheetView`)

- [ ] **Step 1: Add Task 7 & full-project verification assertions to `kapi-money-ios/scripts/verify-swift-project.mjs`**

Verify all 6 views, `@main KapiMoneyApp`, `build-wsl-xtool.sh`, and `.github/workflows/build-kapi-ios.yml` exist and pass end-to-end symbol, route, and test checks.

- [ ] **Step 2: Run verification to confirm Task 7 fails**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --task 7`
Expected: FAIL with missing Task 7 files.

- [ ] **Step 3: Implement `KapiStatsView`, `AssetsAndAccountDetailView`, `BudgetManagementView`, `CategoryManagementView`, `SettingsAndShortcutsGuideView`, `KapiRootContainerView`, `KapiMoneyApp`, `build-wsl-xtool.sh`, and `.github/workflows/build-kapi-ios.yml`**

Implement all remaining screens matching `IMG_2253`–`IMG_2294`, wire deep-link handling (`kapimoney://edit-bill?id=...`) in `KapiRootContainerView`, add `kapi-money-ios/scripts/build-wsl-xtool.sh` for one-command WSL2 `xtool dev` building/installing, and create `.github/workflows/build-kapi-ios.yml` to run `swift test` and package `KapiMoney-iOS.ipa` on GitHub Actions.

- [ ] **Step 4: Run full project verification suite**

Run: `node kapi-money-ios/scripts/verify-swift-project.mjs --all`
Expected: PASS (`All 7 tasks and 100% of Kapi Money spec requirements verified`).

- [ ] **Step 5: Commit**

```bash
git add kapi-money-ios/ .github/workflows/build-kapi-ios.yml
git commit -m "feat(ios): complete Kapi Money stats, assets audit, budget, categories, root app, and xtool/CI workflows"
```
