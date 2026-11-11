import Foundation

public typealias CalendarDaySummary = DailyBudgetCellModel

public struct DailyBudgetCellModel: Identifiable, Equatable, Sendable {
    public var id: String
    public var day: Int
    public var date: Date
    public var isToday: Bool
    public var isPast: Bool
    public var actualSpent: Double
    public var actualIncome: Double
    public var dynamicAvailableBudget: Double
    public var isHighestSpendDayInMonth: Bool

    public var isHighestExpenseDay: Bool { isHighestSpendDayInMonth }
    public var expense: Double { actualSpent }
    public var income: Double { actualIncome }
    public var expenseAmount: Double { actualSpent }
    public var incomeAmount: Double { actualIncome }

    public init(
        id: String,
        day: Int,
        date: Date,
        isToday: Bool,
        isPast: Bool,
        actualSpent: Double,
        actualIncome: Double,
        dynamicAvailableBudget: Double,
        isHighestSpendDayInMonth: Bool = false
    ) {
        self.id = id
        self.day = day
        self.date = date
        self.isToday = isToday
        self.isPast = isPast
        self.actualSpent = actualSpent
        self.actualIncome = actualIncome
        self.dynamicAvailableBudget = dynamicAvailableBudget
        self.isHighestSpendDayInMonth = isHighestSpendDayInMonth
    }
}

public enum DynamicBudgetEngine {
    /// Calculates the dynamic daily available budget:
    /// DailyBudget = max(0, (monthlyBudget - spentBeforeToday) / max(1, remainingDaysIncludingToday))
    public static func calculateDailyBudget(monthlyBudget: Double, spentBeforeToday: Double, remainingDaysIncludingToday: Int) -> Double {
        let remainingBudget = monthlyBudget - spentBeforeToday
        guard remainingBudget > 0 else { return 0.0 }
        let safeDays = max(1, remainingDaysIncludingToday)
        let raw = remainingBudget / Double(safeDays)
        return (raw * 100.0).rounded() / 100.0
    }

    public static func buildMonthDayCells(
        year: Int,
        month: Int,
        today: Date = DefaultCatalog.makeDate(year: 2026, month: 11, day: 10, hour: 12, minute: 0),
        ledger: LedgerItem = DefaultCatalog.defaultLedger(),
        transactions: [TransactionItem]
    ) -> [DailyBudgetCellModel] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday first, matching IMG_2250 & IMG_2264
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let totalDays = range.count
        let todayComps = calendar.dateComponents([.year, .month, .day], from: today)
        let todayDay = (todayComps.year == year && todayComps.month == month) ? (todayComps.day ?? 10) : 10

        var spentByDay: [Int: Double] = [:]
        var incomeByDay: [Int: Double] = [:]

        for tx in transactions where tx.ledgerId == ledger.id && tx.includeInStats {
            let txComps = calendar.dateComponents([.year, .month, .day], from: tx.date)
            guard txComps.year == year, txComps.month == month, let d = txComps.day else { continue }
            if tx.type == .expense {
                let netExpense = max(0.0, tx.amount - tx.discountAmount - tx.refundAmount)
                spentByDay[d, default: 0.0] += netExpense
            } else if tx.type == .income {
                incomeByDay[d, default: 0.0] += tx.amount
            }
        }

        let spentBeforeToday = (1..<max(1, todayDay)).reduce(0.0) { $0 + (spentByDay[$1] ?? 0.0) }
        let remainingDays = max(1, totalDays - todayDay + 1)
        let baseDaily = calculateDailyBudget(
            monthlyBudget: ledger.monthlyBudget,
            spentBeforeToday: spentBeforeToday,
            remainingDaysIncludingToday: remainingDays
        )

        let maxSpend = spentByDay.values.max() ?? 0.0
        var cells: [DailyBudgetCellModel] = []

        for d in 1...totalDays {
            comps.day = d
            let cellDate = calendar.date(from: comps) ?? today
            let dateKey = String(format: "%04d-%02d-%02d", year, month, d)
            let customOrBase = ledger.customDailyBudgets[dateKey] ?? baseDaily
            let spent = spentByDay[d] ?? 0.0
            let inc = incomeByDay[d] ?? 0.0
            cells.append(
                DailyBudgetCellModel(
                    id: dateKey,
                    day: d,
                    date: cellDate,
                    isToday: d == todayDay,
                    isPast: d < todayDay,
                    actualSpent: spent,
                    actualIncome: inc,
                    dynamicAvailableBudget: customOrBase,
                    isHighestSpendDayInMonth: maxSpend > 0 && abs(spent - maxSpend) < 0.001
                )
            )
        }
        return cells
    }
}
