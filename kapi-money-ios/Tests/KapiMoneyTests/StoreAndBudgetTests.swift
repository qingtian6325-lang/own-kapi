import XCTest
@testable import KapiMoneyCore

@MainActor
final class StoreAndBudgetTests: XCTestCase {
    func testCalculatorChainedExpressionEvaluation() {
        XCTAssertEqual(KeypadCalculator.evaluate("15.5+4.5-2"), 18.0, accuracy: 0.001)
        XCTAssertEqual(KeypadCalculator.evaluate("10-25"), 0.0, accuracy: 0.001)
        XCTAssertEqual(KeypadCalculator.evaluate("38.78+"), 38.78, accuracy: 0.001)
    }

    func testDynamicDailyBudgetFormulaAndEdgeCases() {
        let daily = DynamicBudgetEngine.calculateDailyBudget(
            monthlyBudget: 3200.00,
            spentBeforeToday: 1262.52,
            remainingDaysIncludingToday: 21
        )
        XCTAssertEqual(daily, 92.26, accuracy: 0.01)

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

        var edited = tx
        edited.amount = 8.30
        edited.accountId = pbbId
        store.updateTransaction(edited)
        XCTAssertEqual(store.accounts.first(where: { $0.id == tngId })!.balance, initialTng, accuracy: 0.001)
        XCTAssertEqual(store.auditLogs.first?.action, .updated)

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

    func testCleanEmptyAppStateAndCSVImportExport() {
        let cleanState = KapiStore.makeCleanEmptyAppState()
        XCTAssertTrue(cleanState.transactions.isEmpty)
        XCTAssertTrue(cleanState.auditLogs.isEmpty)
        XCTAssertEqual(cleanState.accounts.reduce(0.0) { $0 + $1.balance }, 0.0, accuracy: 0.001)

        let store = KapiStore(inMemory: true)
        store.resetToCleanEmpty()
        XCTAssertEqual(store.totalRecordsCount, 0)
        XCTAssertEqual(store.recordedDaysCount, 0)
        XCTAssertEqual(store.streakDaysCount, 0)
        XCTAssertEqual(store.netWorth, 0.0, accuracy: 0.001)

        let parsed = KapiCSVService.parseKapiCSV(KapiCSVService.userExportedCSV)
        XCTAssertEqual(parsed.count, 151)
        let transfers = parsed.filter { $0.type == .transfer }
        let expensesAndIncomes = parsed.filter { $0.type != .transfer }
        XCTAssertEqual(transfers.count, 11)
        XCTAssertEqual(expensesAndIncomes.count, 140)

        let importedCount = store.importKapiCSV(KapiCSVService.userExportedCSV, replaceExisting: true)
        XCTAssertEqual(importedCount, 151)
        XCTAssertEqual(store.totalRecordsCount, 151)
        XCTAssertGreaterThan(store.recordedDaysCount, 10)

        let exported = store.exportKapiCSV()
        XCTAssertTrue(exported.contains("日期,时间,类型,金额,一级分类,二级分类,标签,账户,计入收支,计入预算,所属账本,备注,分摊明细"))
        XCTAssertTrue(exported.contains("日期,时间,类型,金额,转入账户,转出账户,备注"))
        XCTAssertTrue(exported.contains("账户互转"))
    }

    func testLedgerTagAndScheduledTransactionsCRUD() {
        let store = KapiStore(inMemory: true)

        // Ledger CRUD
        let initialLedgerCount = store.ledgers.count
        store.addLedger(name: "旅行账本", currency: .sgd, monthlyBudget: 1500.0)
        XCTAssertEqual(store.ledgers.count, initialLedgerCount + 1)
        XCTAssertEqual(store.currentLedger.name, "旅行账本")
        XCTAssertEqual(store.currentLedger.currency, .sgd)
        XCTAssertEqual(store.currentLedger.monthlyBudget, 1500.0, accuracy: 0.001)

        let newId = store.currentLedgerId
        store.renameLedger(id: newId, newName: "新马泰之旅")
        XCTAssertEqual(store.currentLedger.name, "新马泰之旅")

        store.switchLedger(id: "ledger_main")
        XCTAssertEqual(store.currentLedgerId, "ledger_main")

        store.deleteLedger(id: newId)
        XCTAssertEqual(store.ledgers.count, initialLedgerCount)

        // Tag CRUD
        let initialTagCount = store.tags.count
        store.addTag("年货")
        XCTAssertEqual(store.tags.count, initialTagCount + 1)
        XCTAssertTrue(store.tags.contains("年货"))

        let taggedTx = TransactionItem(
            ledgerId: store.currentLedgerId,
            type: .expense,
            amount: 88.0,
            primaryCategoryId: "餐饮",
            tags: ["年货", "家庭"]
        )
        store.addTransaction(taggedTx)
        XCTAssertEqual(store.transactions(forTag: "年货").count, 1)

        store.deleteTag("年货")
        XCTAssertFalse(store.tags.contains("年货"))

        // Scheduled Bookkeeping
        let sched = ScheduledTransactionItem(
            title: "健身房月卡",
            type: .expense,
            amount: 199.0,
            categoryPath: "休闲娱乐-运动健身",
            accountName: "PBBank"
        )
        store.addScheduledTransaction(sched)
        XCTAssertTrue(store.scheduledTransactions.contains(where: { $0.id == sched.id }))

        store.toggleScheduledTransaction(id: sched.id)
        XCTAssertFalse(store.scheduledTransactions.first(where: { $0.id == sched.id })!.isEnabled)

        let txCountBefore = store.transactions.count
        store.executeScheduledTransactionNow(id: sched.id)
        XCTAssertEqual(store.transactions.count, txCountBefore + 1)
        XCTAssertEqual(store.transactions.first?.amount, 199.0, accuracy: 0.001)

        store.deleteScheduledTransaction(id: sched.id)
        XCTAssertFalse(store.scheduledTransactions.contains(where: { $0.id == sched.id }))

        // User settings
        store.setNickname("景豪专属")
        XCTAssertEqual(store.userNickname, "景豪专属")
    }
}
