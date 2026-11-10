import SwiftUI

public struct KapiStatsView: View {
    @ObservedObject public var store: KapiStore
    public var onOpenDrawer: () -> Void
    public var onSwitchToHome: () -> Void
    public var onOpenAssets: () -> Void

    @State private var selectedPeriod: String = "月" // 周 | 月 | 年 | 自定义
    @State private var selectedChartType: TransactionType = .expense
    @State private var selectedLedgerFilterId: String? = nil // nil = current ledger
    @State private var selectedFilterType: String = "全部" // 全部 | 仅支出 | 仅收入

    @State private var statsYear: Int = 2026
    @State private var statsMonth: Int = 11
    @State private var statsWeekOffset: Int = 0
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()

    public init(
        store: KapiStore,
        onOpenDrawer: @escaping () -> Void,
        onSwitchToHome: @escaping () -> Void,
        onOpenAssets: @escaping () -> Void
    ) {
        self.store = store
        self.onOpenDrawer = onOpenDrawer
        self.onSwitchToHome = onSwitchToHome
        self.onOpenAssets = onOpenAssets
    }

    private var periodTransactions: [TransactionItem] {
        let cal = Calendar(identifier: .gregorian)
        let targetLedgerId = selectedLedgerFilterId ?? store.currentLedgerId

        return store.transactions.filter { tx in
            if selectedLedgerFilterId != "all" && tx.ledgerId != targetLedgerId {
                return false
            }
            guard tx.includeInStats else { return false }

            if selectedFilterType == "仅支出" && tx.type != .expense { return false }
            if selectedFilterType == "仅收入" && tx.type != .income { return false }

            switch selectedPeriod {
            case "周":
                let now = Date()
                guard let baseDate = cal.date(byAdding: .day, value: statsWeekOffset * 7, to: now) else { return true }
                guard let weekStart = cal.date(byAdding: .day, value: -6, to: baseDate) else { return true }
                return tx.date >= weekStart && tx.date <= baseDate
            case "月":
                let txComps = cal.dateComponents([.year, .month], from: tx.date)
                return txComps.year == statsYear && txComps.month == statsMonth
            case "年":
                let txYear = cal.component(.year, from: tx.date)
                return txYear == statsYear
            case "自定义":
                return tx.date >= customStartDate && tx.date <= customEndDate
            default:
                return true
            }
        }
    }

    private var periodLabelText: String {
        switch selectedPeriod {
        case "周":
            if statsWeekOffset == 0 {
                return "本周 (最近 7 天)"
            } else if statsWeekOffset < 0 {
                return String(format: "往前第 %d 周", abs(statsWeekOffset))
            } else {
                return String(format: "往后第 %d 周", statsWeekOffset)
            }
        case "月":
            return String(format: "%d年 %d月", statsYear, statsMonth)
        case "年":
            return String(format: "%d年 全年", statsYear)
        case "自定义":
            let f = DateFormatter()
            f.dateFormat = "yyyy/MM/dd"
            return "\(f.string(from: customStartDate)) ~ \(f.string(from: customEndDate))"
        default:
            return "全部历史账单"
        }
    }

    private func navigatePeriod(forward: Bool) {
        switch selectedPeriod {
        case "月":
            if forward {
                if statsMonth == 12 {
                    statsMonth = 1
                    statsYear += 1
                } else {
                    statsMonth += 1
                }
            } else {
                if statsMonth == 1 {
                    statsMonth = 12
                    statsYear -= 1
                } else {
                    statsMonth -= 1
                }
            }
        case "周":
            statsWeekOffset += (forward ? 1 : -1)
        case "年":
            statsYear += (forward ? 1 : -1)
        default:
            break
        }
    }

    private var balanceCardTitle: String {
        switch selectedPeriod {
        case "周": return "本周结余"
        case "月": return "本月结余"
        case "年": return "年度结余"
        default: return "累计结余"
        }
    }

    private var totalExpense: Double {
        periodTransactions.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
    }

    private var totalIncome: Double {
        periodTransactions.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
    }

    private var netBalance: Double {
        totalIncome - totalExpense
    }

    private var categoryBreakdown: [(name: String, icon: String, amount: Double, percent: Double, color: Color)] {
        let expenses = periodTransactions.filter { $0.type == .expense }
        let total = max(1.0, expenses.reduce(0.0) { $0 + $1.amount })
        var grouped: [String: (icon: String, sum: Double)] = [:]
        for tx in expenses {
            let primary = tx.categoryPath.components(separatedBy: "-").first ?? tx.categoryPath
            let prev = grouped[primary] ?? (icon: tx.iconName, sum: 0)
            grouped[primary] = (icon: prev.icon, sum: prev.sum + tx.amount)
        }
        let palette: [Color] = [
            KapiTheme.expenseBlue,
            Color(hex: 0x5B86F7),
            KapiTheme.incomeOrange,
            KapiTheme.balanceGreen,
            Color(hex: 0x9B6EF3)
        ]
        return grouped
            .map { (key, val) in (name: key, icon: val.icon, amount: val.sum, percent: val.sum / total) }
            .sorted { $0.amount > $1.amount }
            .enumerated()
            .map { idx, item in
                (
                    name: item.name,
                    icon: item.icon,
                    amount: item.amount,
                    percent: item.percent,
                    color: palette[idx % palette.count]
                )
            }
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                topBar
                periodSegmentedControl
                capybaraBalanceCard
                donutBreakdownCard
                dailyTrendBarCard
                top10SingleExpenseCard
                tabularBillSummaryCard
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background(KapiTheme.background.ignoresSafeArea())
    }

    // MARK: - Top Navigation Bar (< 记录 | 统计 ⌄ | 全部账本 ⌄ | 筛选)

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: onSwitchToHome) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                    Text("记录")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(KapiTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)

            Menu {
                Button("记录 (首页)") { onSwitchToHome() }
                Button("Kapi (图表统计)") {}
                Button("资产管理") { onOpenAssets() }
            } label: {
                HStack(spacing: 4) {
                    Text("统计")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(KapiTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(KapiTheme.textSecondary)
                }
            }

            Spacer()

            Menu {
                Button("当前账本 (\(store.currentLedgerName))") { selectedLedgerFilterId = store.currentLedgerId }
                Button("全部账本合并") { selectedLedgerFilterId = "all" }
                Divider()
                ForEach(store.ledgers) { l in
                    Button(l.name) { selectedLedgerFilterId = l.id }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedLedgerFilterId == "all" ? "全部账本" : (store.ledgers.first(where: { $0.id == selectedLedgerFilterId })?.name ?? store.currentLedgerName))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(KapiTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(KapiTheme.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white))
            }

            Menu {
                Button("全部类型") { selectedFilterType = "全部" }
                Button("仅看支出") { selectedFilterType = "仅支出" }
                Button("仅看收入") { selectedFilterType = "仅收入" }
            } label: {
                HStack(spacing: 3) {
                    Text(selectedFilterType == "全部" ? "筛选" : selectedFilterType)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(KapiTheme.textPrimary)
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 11))
                        .foregroundColor(KapiTheme.expenseBlue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white))
            }
        }
    }

    // MARK: - Period Control (周 | 月 | 年 | 自定义 + 前进后退导航)

    private var periodSegmentedControl: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(["周", "月", "年", "自定义"], id: \.self) { period in
                    Button {
                        selectedPeriod = period
                    } label: {
                        Text(period)
                            .font(.system(size: 13, weight: selectedPeriod == period ? .bold : .medium))
                            .foregroundColor(selectedPeriod == period ? KapiTheme.textPrimary : KapiTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedPeriod == period ? Color.white : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xE9ECF4)))

            // Forward/Backward Period Selector Bar
            HStack {
                Button {
                    navigatePeriod(forward: false)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("往前")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(KapiTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(periodLabelText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(KapiTheme.textPrimary)

                Spacer()

                Button {
                    navigatePeriod(forward: true)
                } label: {
                    HStack(spacing: 2) {
                        Text("往后")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(KapiTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
            }

            if selectedPeriod == "自定义" {
                HStack(spacing: 8) {
                    Text("起:")
                        .font(.system(size: 11))
                        .foregroundColor(KapiTheme.textSecondary)
                    DatePicker("", selection: $customStartDate, displayedComponents: .date)
                        .labelsHidden()

                    Text("止:")
                        .font(.system(size: 11))
                        .foregroundColor(KapiTheme.textSecondary)
                    DatePicker("", selection: $customEndDate, displayedComponents: .date)
                        .labelsHidden()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            }
        }
    }

    // MARK: - Balance Overview Banner (总支出, 总收入, 净结余 一样大三等分展示)

    private var capybaraBalanceCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                // Column 1: 总支出
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Circle().fill(KapiTheme.expenseBlue).frame(width: 6, height: 6)
                        Text("总支出")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(KapiTheme.textSecondary)
                    }
                    Text(KapiTheme.formatRM(totalExpense))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(KapiTheme.expenseBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xF2F5FC)))

                // Column 2: 总收入
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Circle().fill(KapiTheme.incomeOrange).frame(width: 6, height: 6)
                        Text("总收入")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(KapiTheme.textSecondary)
                    }
                    Text(KapiTheme.formatRM(totalIncome))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(KapiTheme.incomeOrange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xFFF7F0)))

                // Column 3: 净结余
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Circle().fill(netBalance >= 0 ? KapiTheme.balanceGreen : KapiTheme.dangerRed).frame(width: 6, height: 6)
                        Text(netBalance >= 0 ? "净结余" : "超支")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(KapiTheme.textSecondary)
                    }
                    Text(KapiTheme.formatRM(netBalance))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(netBalance >= 0 ? KapiTheme.balanceGreen : KapiTheme.dangerRed)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(netBalance >= 0 ? Color(hex: 0xF0F9F4) : Color(hex: 0xFEECEC)))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - Donut Chart: 支出分类构成 (IMG_2254)

    private var donutBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("支出分类构成")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)
                Spacer()
                Text("按一级分类")
                    .font(.system(size: 11))
                    .foregroundColor(KapiTheme.textMuted)
            }

            HStack(spacing: 20) {
                let firstShare = categoryBreakdown.first?.percent ?? 0.0
                let secondShare = categoryBreakdown.dropFirst().first?.percent ?? 0.0
                ZStack {
                    Circle()
                        .stroke(Color(hex: 0xEEF0F6), lineWidth: 16)
                        .frame(width: 110, height: 110)

                    if firstShare > 0 {
                        Circle()
                            .trim(from: 0, to: CGFloat(firstShare))
                            .stroke(KapiTheme.expenseBlue, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 110, height: 110)
                    }

                    if secondShare > 0 {
                        Circle()
                            .trim(from: CGFloat(min(0.98, firstShare + 0.02)), to: CGFloat(min(1.0, firstShare + secondShare)))
                            .stroke(Color(hex: 0x5B86F7), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 110, height: 110)
                    }

                    VStack(spacing: 2) {
                        Text("总支出")
                            .font(.system(size: 10))
                            .foregroundColor(KapiTheme.textMuted)
                        Text(KapiTheme.formatRM(totalExpense))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(KapiTheme.textPrimary)
                    }
                }
                .padding(.leading, 8)

                VStack(alignment: .leading, spacing: 8) {
                    if categoryBreakdown.isEmpty {
                        Text("暂无支出分类数据")
                            .font(.system(size: 13))
                            .foregroundColor(KapiTheme.textMuted)
                    } else {
                        ForEach(Array(categoryBreakdown.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(row.color)
                                    .frame(width: 8, height: 8)
                                Text(row.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(KapiTheme.textPrimary)
                                Text(String(format: "%.1f%%", row.percent * 100))
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(KapiTheme.textMuted)
                                Spacer()
                                Text(KapiTheme.formatRM(row.amount))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(KapiTheme.textPrimary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - Bar Chart: 每日支出趋势 (IMG_2255)

    private var dailyTrendBarCard: some View {
        let cal = Calendar(identifier: .gregorian)
        let expenses = periodTransactions.filter { $0.type == .expense }
        let labels = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let weekdayMap = [2, 3, 4, 5, 6, 7, 1] // Gregorian weekday: 2=Mon ... 7=Sat, 1=Sun
        let bars: [(label: String, value: Double)] = zip(labels, weekdayMap).map { label, wd in
            let sum = expenses
                .filter { cal.component(.weekday, from: $0.date) == wd }
                .reduce(0.0) { $0 + $1.amount }
            return (label: label, value: sum)
        }
        let maxVal = max(1.0, bars.map(\.value).max() ?? 1.0)
        let dailyAvg = totalExpense / 7.0

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("每日支出趋势")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)
                Spacer()
                Text("日均 \(KapiTheme.formatRM(dailyAvg))")
                    .font(.system(size: 11))
                    .foregroundColor(KapiTheme.textMuted)
            }

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(bars, id: \.label) { bar in
                    VStack(spacing: 6) {
                        if bar.value > 0 {
                            Text(String(format: "%.0f", bar.value))
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(KapiTheme.expenseBlue)
                        }
                        RoundedRectangle(cornerRadius: 6)
                            .fill(bar.value > 0 ? KapiTheme.expenseBlue : Color(hex: 0xEEF0F6))
                            .frame(height: max(8, CGFloat(bar.value / maxVal) * 110))
                        Text(bar.label)
                            .font(.system(size: 10))
                            .foregroundColor(KapiTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 145, alignment: .bottom)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - Top 10 List: 单笔支出排行 (IMG_2256)

    private var top10SingleExpenseCard: some View {
        let topExpenses = periodTransactions
            .filter { $0.type == .expense }
            .sorted { $0.amount > $1.amount }
            .prefix(10)

        return VStack(alignment: .leading, spacing: 12) {
            Text("单笔支出排行")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(KapiTheme.textPrimary)

            if topExpenses.isEmpty {
                Text("暂无单笔支出记录")
                    .font(.system(size: 13))
                    .foregroundColor(KapiTheme.textMuted)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(topExpenses.enumerated()), id: \.element.id) { idx, item in
                    HStack(spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(idx < 3 ? KapiTheme.expenseBlue : KapiTheme.textMuted)
                            .frame(width: 18)

                        KapiStickerIconView(
                            iconName: item.iconName,
                            categoryName: item.categoryPath,
                            transactionType: .expense,
                            size: 32
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.categoryPath)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(KapiTheme.textPrimary)
                            if !item.note.isEmpty {
                                Text(item.note)
                                    .font(.system(size: 11))
                                    .foregroundColor(KapiTheme.textMuted)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Text("-\(KapiTheme.formatRM(item.amount))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(KapiTheme.expenseBlue)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - Tabular Summary: 账单汇总 (IMG_2257)

    private var tabularBillSummaryCard: some View {
        let dayGroups = store.groupedTransactionsByDay().prefix(15)
        let cal = Calendar(identifier: .gregorian)

        return VStack(alignment: .leading, spacing: 12) {
            Text("账单汇总")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(KapiTheme.textPrimary)

            VStack(spacing: 0) {
                HStack {
                    Text("时间").frame(maxWidth: .infinity, alignment: .leading)
                    Text("收入").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("支出").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("结余").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(KapiTheme.textSecondary)
                .padding(10)
                .background(Color(hex: 0xF5F6FA))

                if dayGroups.isEmpty {
                    HStack {
                        Text("暂无账单").frame(maxWidth: .infinity, alignment: .leading)
                        Text("RM0.00").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("RM0.00").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("RM0.00").frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(KapiTheme.textMuted)
                    .padding(10)
                } else {
                    ForEach(Array(dayGroups.enumerated()), id: \.offset) { idx, group in
                        let inc = group.items.filter { $0.type == .income && $0.includeInStats }.reduce(0.0) { $0 + $1.amount }
                        let exp = group.items.filter { $0.type == .expense && $0.includeInStats }.reduce(0.0) { $0 + $1.amount }
                        let net = inc - exp
                        let m = cal.component(.month, from: group.date)
                        let d = cal.component(.day, from: group.date)

                        HStack {
                            Text("\(m)月\(d)日").frame(maxWidth: .infinity, alignment: .leading)
                            Text(KapiTheme.formatRM(inc)).frame(maxWidth: .infinity, alignment: .trailing)
                            Text(KapiTheme.formatRM(exp)).frame(maxWidth: .infinity, alignment: .trailing)
                            Text(KapiTheme.formatRM(net)).frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(.system(size: 12, design: .rounded))
                        .padding(10)

                        if idx + 1 < dayGroups.count {
                            Divider()
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(KapiTheme.divider, lineWidth: 1))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }
}
