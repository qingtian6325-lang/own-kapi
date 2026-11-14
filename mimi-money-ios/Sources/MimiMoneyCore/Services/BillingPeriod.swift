import Foundation

/// Custom monthly billing cycle (e.g. start day 25 → 25th … day-before-next-25th).
public struct BillingPeriod: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public var dayCount: Int {
        let cal = Calendar(identifier: .gregorian)
        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end)
        return max(1, (cal.dateComponents([.day], from: s, to: e).day ?? 0) + 1)
    }

    public func contains(_ date: Date) -> Bool {
        let cal = Calendar(identifier: .gregorian)
        let d = cal.startOfDay(for: date)
        return d >= cal.startOfDay(for: start) && d <= cal.startOfDay(for: end)
    }

    public var displayRangeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }
}

public enum BillingPeriodEngine {
    /// Clamp to 1…28 so every month has a valid start day.
    public static func clampedStartDay(_ day: Int) -> Int {
        min(28, max(1, day))
    }

    public static func period(containing date: Date, startDay: Int, calendar: Calendar = Calendar(identifier: .gregorian)) -> BillingPeriod {
        let day = clampedStartDay(startDay)
        let cal = calendar
        let todayStart = cal.startOfDay(for: date)
        let comps = cal.dateComponents([.year, .month, .day], from: todayStart)
        let y = comps.year ?? 2026
        let m = comps.month ?? 1
        let d = comps.day ?? 1

        let startThisMonth = dateOn(year: y, month: m, day: day, calendar: cal)

        let periodStart: Date
        if d >= day {
            periodStart = startThisMonth
        } else {
            periodStart = cal.date(byAdding: .month, value: -1, to: startThisMonth) ?? startThisMonth
        }

        let nextStart = cal.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart
        let periodEndDay = cal.date(byAdding: .day, value: -1, to: nextStart) ?? periodStart
        let periodEnd = endOfDay(periodEndDay, calendar: cal)
        return BillingPeriod(start: periodStart, end: periodEnd)
    }

    public static func remainingDaysIncludingToday(in period: BillingPeriod, today: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> Int {
        let cal = calendar
        let t = cal.startOfDay(for: today)
        let end = cal.startOfDay(for: period.end)
        guard t <= end else { return 1 }
        return max(1, (cal.dateComponents([.day], from: t, to: end).day ?? 0) + 1)
    }

    public static func spentBeforeToday(
        transactions: [TransactionItem],
        ledgerId: String,
        period: BillingPeriod,
        today: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Double {
        let cal = calendar
        let todayStart = cal.startOfDay(for: today)
        return transactions.reduce(0.0) { acc, tx in
            guard tx.ledgerId == ledgerId,
                  tx.includeInStats,
                  tx.type == .expense,
                  period.contains(tx.date),
                  cal.startOfDay(for: tx.date) < todayStart else { return acc }
            return acc + max(0.0, tx.amount - tx.discountAmount - tx.refundAmount)
        }
    }

    private static func dateOn(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        var comps = DateComponents(year: year, month: month, day: day)
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        return calendar.date(from: comps) ?? Date()
    }

    private static func endOfDay(_ date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: start) ?? start
    }
}
