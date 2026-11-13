import SwiftUI

/// 统计「分类构成」点进后的分类账单页（金标：交通等）
/// 顶栏分类名 → 月汇总 → 可选二级构成 → 按日账单列表 → 点行打开账单详情
public struct CategoryBillsListView: View {
    @ObservedObject public var store: MimiStore
    public var categoryName: String
    public var transactionType: TransactionType
    public var year: Int
    public var month: Int
    public var onSelectTransaction: (TransactionItem) -> Void
    public var onDismiss: () -> Void

    @State private var selectedSubcategory: String? = nil
    @State private var showSubOnly: Bool = false

    public init(
        store: MimiStore,
        categoryName: String,
        transactionType: TransactionType,
        year: Int,
        month: Int,
        onSelectTransaction: @escaping (TransactionItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.store = store
        self.categoryName = categoryName
        self.transactionType = transactionType
        self.year = year
        self.month = month
        self.onSelectTransaction = onSelectTransaction
        self.onDismiss = onDismiss
    }

    private var cal: Calendar { Calendar(identifier: .gregorian) }

    private var monthTransactions: [TransactionItem] {
        store.transactions.filter { tx in
            guard tx.type == transactionType else { return false }
            let y = cal.component(.year, from: tx.date)
            let m = cal.component(.month, from: tx.date)
            guard y == year && m == month else { return false }
            let primary = tx.categoryPath.components(separatedBy: "-").first ?? tx.categoryPath
            guard primary == categoryName else { return false }
            if let sub = selectedSubcategory, showSubOnly {
                let leaf = tx.categoryPath.components(separatedBy: "-").last ?? tx.categoryPath
                return leaf == sub || tx.categoryPath.hasSuffix("-\(sub)")
            }
            return true
        }
        .sorted { $0.date > $1.date }
    }

    private var monthTotal: Double {
        monthTransactions.reduce(0.0) { $0 + $1.amount }
    }

    private var previousMonthTotal: Double {
        var comps = DateComponents(year: year, month: month, day: 1)
        guard let thisMonth = cal.date(from: comps),
              let prev = cal.date(byAdding: .month, value: -1, to: thisMonth) else { return 0 }
        let py = cal.component(.year, from: prev)
        let pm = cal.component(.month, from: prev)
        return store.transactions.filter { tx in
            guard tx.type == transactionType else { return false }
            let y = cal.component(.year, from: tx.date)
            let m = cal.component(.month, from: tx.date)
            guard y == py && m == pm else { return false }
            let primary = tx.categoryPath.components(separatedBy: "-").first ?? tx.categoryPath
            return primary == categoryName
        }.reduce(0.0) { $0 + $1.amount }
    }

    private var vsLastMonthPercent: Double? {
        guard previousMonthTotal > 0.009 else { return monthTotal > 0 ? nil : 0 }
        return ((monthTotal - previousMonthTotal) / previousMonthTotal) * 100.0
    }

    private var subcategoryBreakdown: [(name: String, icon: String, amount: Double, percent: Double, count: Int)] {
        let total = max(0.009, monthTotal)
        var map: [String: (icon: String, sum: Double, count: Int)] = [:]
        for tx in monthTransactions where selectedSubcategory == nil || !showSubOnly {
            let parts = tx.categoryPath.components(separatedBy: "-")
            let leaf = parts.count > 1 ? parts[1] : parts[0]
            let prev = map[leaf] ?? (icon: tx.iconName, sum: 0, count: 0)
            map[leaf] = (icon: prev.icon.isEmpty ? tx.iconName : prev.icon, sum: prev.sum + tx.amount, count: prev.count + 1)
        }
        return map
            .map { (name: $0.key, icon: $0.value.icon, amount: $0.value.sum, percent: $0.value.sum / total, count: $0.value.count) }
            .sorted { $0.amount > $1.amount }
    }

    private var dayGroups: [(date: Date, items: [TransactionItem])] {
        let dict = Dictionary(grouping: monthTransactions) { tx in
            cal.startOfDay(for: tx.date)
        }
        return dict.keys.sorted(by: >).map { ($0, dict[$0] ?? []) }
    }

    private var rangeLabel: String {
        String(format: "%04d-%02d-01—%04d-%02d-%02d", year, month, year, month, daysInMonth)
    }

    private var daysInMonth: Int {
        var comps = DateComponents(year: year, month: month)
        comps.day = 1
        guard let start = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: start) else { return 30 }
        return range.count
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                summaryCard
                if !subcategoryBreakdown.isEmpty && !(showSubOnly && selectedSubcategory != nil) {
                    compositionCard
                }
                rangeAndTotalRow
                billsSection
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background(MimiTheme.background.ignoresSafeArea())
        .navigationTitle(displayTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    if showSubOnly {
                        showSubOnly = false
                        selectedSubcategory = nil
                    } else {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .mimiFont(15, weight: .semibold)
                        .foregroundColor(MimiTheme.textPrimary)
                }
            }
        }
    }

    private var displayTitle: String {
        if showSubOnly, let sub = selectedSubcategory { return sub }
        return categoryName
    }

    private var summaryCard: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(transactionType == .expense ? "支出" : "收入")
                    .mimiFont(13)
                    .foregroundColor(MimiTheme.textSecondary)
                Text(MimiTheme.formatRM(monthTotal))
                    .mimiFont(26, weight: .bold, design: .rounded)
                    .foregroundColor(transactionType == .expense ? MimiTheme.expenseBlue : MimiTheme.incomeOrange)
                if let pct = vsLastMonthPercent {
                    Text(String(format: "和上月比 %@ %.0f%%", pct >= 0 ? "↑" : "↓", abs(pct)))
                        .mimiFont(12)
                        .foregroundColor(MimiTheme.textMuted)
                } else if previousMonthTotal < 0.009 && monthTotal > 0 {
                    Text("和上月比 ↑ —")
                        .mimiFont(12)
                        .foregroundColor(MimiTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("账单数")
                    .mimiFont(13)
                    .foregroundColor(MimiTheme.textSecondary)
                Text("\(monthTransactions.count)")
                    .mimiFont(26, weight: .bold, design: .rounded)
                    .foregroundColor(MimiTheme.textPrimary)
                Text("本月记录")
                    .mimiFont(12)
                    .foregroundColor(MimiTheme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(MimiTheme.cardBackground))
    }

    private var compositionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(transactionType == .expense ? "支出分类构成" : "收入分类构成")
                .mimiFont(15, weight: .bold)
                .foregroundColor(MimiTheme.textPrimary)

            ForEach(Array(subcategoryBreakdown.enumerated()), id: \.offset) { _, row in
                Button {
                    selectedSubcategory = row.name
                    showSubOnly = true
                } label: {
                    HStack(spacing: 10) {
                        MimiStickerIconView(
                            iconName: row.icon,
                            categoryName: row.name,
                            transactionType: transactionType,
                            size: 32
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(row.name)
                                    .mimiFont(14, weight: .semibold)
                                    .foregroundColor(MimiTheme.textPrimary)
                                Text(String(format: "%.2f%%", row.percent * 100))
                                    .mimiFont(12)
                                    .foregroundColor(MimiTheme.textMuted)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(MimiTheme.fillSubtle).frame(height: 6)
                                    Capsule()
                                        .fill(MimiTheme.expenseBlue.opacity(0.85))
                                        .frame(width: max(4, geo.size.width * CGFloat(row.percent)), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(MimiTheme.formatRM(row.amount))
                                .mimiFont(14, weight: .bold, design: .rounded)
                                .foregroundColor(MimiTheme.textPrimary)
                            Text("\(row.count)笔")
                                .mimiFont(11)
                                .foregroundColor(MimiTheme.textMuted)
                        }
                        Image(systemName: "chevron.right")
                            .mimiFont(11, weight: .semibold)
                            .foregroundColor(MimiTheme.textMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(MimiTheme.cardBackground))
    }

    private var rangeAndTotalRow: some View {
        HStack {
            Text(rangeLabel)
                .mimiFont(13, weight: .medium)
                .foregroundColor(MimiTheme.textSecondary)
            Spacer()
            Text("\(transactionType == .expense ? "月支出" : "月收入")\(MimiTheme.formatRM(monthTotal))")
                .mimiFont(13, weight: .medium)
                .foregroundColor(MimiTheme.textSecondary)
        }
        .padding(.horizontal, 4)
    }

    private var billsSection: some View {
        Group {
            if dayGroups.isEmpty {
                Text("本月暂无账单")
                    .mimiFont(14)
                    .foregroundColor(MimiTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(RoundedRectangle(cornerRadius: 16).fill(MimiTheme.cardBackground))
            } else {
                ForEach(Array(dayGroups.enumerated()), id: \.offset) { _, group in
                    dayCard(date: group.date, items: group.items)
                }
            }
        }
    }

    private func dayCard(date: Date, items: [TransactionItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(formatDayHeader(date))
                .mimiFont(13, weight: .semibold)
                .foregroundColor(MimiTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)

            ForEach(Array(items.enumerated()), id: \.element.id) { idx, tx in
                Button {
                    onSelectTransaction(tx)
                } label: {
                    HStack(spacing: 12) {
                        MimiStickerIconView(
                            iconName: tx.iconName,
                            categoryName: tx.categoryPath,
                            transactionType: tx.type,
                            size: 36
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(leafTitle(tx))
                                .mimiFont(15, weight: .semibold)
                                .foregroundColor(MimiTheme.textPrimary)
                                .lineLimit(1)
                            Text(metaLine(tx))
                                .mimiFont(12)
                                .foregroundColor(MimiTheme.textMuted)
                                .lineLimit(1)
                            if !tx.accountName.isEmpty {
                                Text(tx.accountName)
                                    .mimiFont(11, weight: .medium)
                                    .foregroundColor(MimiTheme.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(MimiTheme.fillSubtle))
                            }
                        }
                        Spacer(minLength: 8)
                        Text(tx.type == .expense || tx.type == .transfer
                             ? "-\(MimiTheme.formatRM(tx.amount))"
                             : MimiTheme.formatRM(tx.amount))
                            .mimiFont(16, weight: .bold, design: .rounded)
                            .foregroundColor(tx.type == .expense || tx.type == .transfer
                                             ? MimiTheme.expenseBlue
                                             : MimiTheme.incomeOrange)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if idx < items.count - 1 {
                    Divider().padding(.leading, 62)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(MimiTheme.cardBackground))
    }

    private func leafTitle(_ tx: TransactionItem) -> String {
        tx.categoryPath.components(separatedBy: "-").last ?? tx.categoryPath
    }

    private func metaLine(_ tx: TransactionItem) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let clock = f.string(from: tx.date)
        let note = tx.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.isEmpty { return clock }
        return "\(clock) | \(note)"
    }

    private func formatDayHeader(_ date: Date) -> String {
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let weekday = cal.component(.weekday, from: date)
        let names = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let w = (weekday >= 1 && weekday <= 7) ? names[weekday] : ""
        return "\(m)月\(d)日 (\(w))"
    }
}
