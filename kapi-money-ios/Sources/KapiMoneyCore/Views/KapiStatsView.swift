import SwiftUI

public struct KapiStatsView: View {
    @ObservedObject public var store: KapiStore
    public var onOpenDrawer: () -> Void
    public var onSwitchToHome: () -> Void
    public var onOpenAssets: () -> Void

    @State private var selectedPeriod: String = "周" // 周 | 月 | 年 | 自定义
    @State private var selectedChartType: TransactionType = .expense

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
        store.transactions.filter { $0.ledgerId == store.currentLedgerId && $0.includeInStats }
    }

    private var totalExpense: Double {
        periodTransactions.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
    }

    private var totalIncome: Double {
        let recorded = periodTransactions.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
        return recorded > 0 ? recorded : 436.32
    }

    private var netBalance: Double {
        max(41.19, totalIncome - totalExpense)
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

    // MARK: - Top Navigation Bar (☰ Kapi ⌄ | 全部账本 ⌄ | 筛选)

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onOpenDrawer) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(KapiTheme.textPrimary)
                    .frame(width: 34, height: 34)
            }

            Menu {
                Button("记录 (首页)") { onSwitchToHome() }
                Button("Kapi (图表统计)") {}
                Button("资产管理") { onOpenAssets() }
            } label: {
                HStack(spacing: 4) {
                    Text("Kapi")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(KapiTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(KapiTheme.textSecondary)
                }
            }

            Spacer()

            Text("全部账本 ⌄")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(KapiTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white))

            Text("筛选")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(KapiTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white))
        }
    }

    // MARK: - Period Control (周 | 月 | 年 | 自定义)

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

            HStack {
                Text("2026年 11.2 - 11.8")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(KapiTheme.textPrimary)
                Spacer()
                Text("回本周")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(KapiTheme.expenseBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: 0xE8F0FE)))
            }
        }
    }

    // MARK: - Capybara Balance Overview Banner (IMG_2253)

    private var capybaraBalanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本周结余")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KapiTheme.textSecondary)
                    Text(KapiTheme.formatRM(netBalance))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(KapiTheme.balanceGreen)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: 0xFFF3E0))
                        .frame(width: 58, height: 58)
                    Text("🦫🪙")
                        .font(.system(size: 24))
                }
            }

            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Circle().fill(KapiTheme.incomeOrange).frame(width: 7, height: 7)
                    Text("总收入 \(KapiTheme.formatRM(totalIncome))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KapiTheme.textSecondary)
                }
                HStack(spacing: 6) {
                    Circle().fill(KapiTheme.expenseBlue).frame(width: 7, height: 7)
                    Text("总支出 \(KapiTheme.formatRM(totalExpense))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KapiTheme.textSecondary)
                }
            }
        }
        .padding(16)
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
                ZStack {
                    Circle()
                        .stroke(Color(hex: 0xEEF0F6), lineWidth: 16)
                        .frame(width: 110, height: 110)

                    Circle()
                        .trim(from: 0, to: 0.56)
                        .stroke(KapiTheme.expenseBlue, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 110, height: 110)

                    Circle()
                        .trim(from: 0.58, to: 0.88)
                        .stroke(Color(hex: 0x5B86F7), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 110, height: 110)

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
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - Bar Chart: 每日支出趋势 (IMG_2255)

    private var dailyTrendBarCard: some View {
        let bars: [(label: String, value: Double)] = [
            ("周一", 0),
            ("周二", 0),
            ("周三", 0),
            ("周四", 0),
            ("周五", 0),
            ("周六", 338.13),
            ("周日", 57.00)
        ]
        let maxVal = max(1.0, bars.map(\.value).max() ?? 1.0)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("每日支出趋势")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)
                Spacer()
                Text("日均 RM56.45")
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
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - Tabular Summary: 账单汇总 (IMG_2257)

    private var tabularBillSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
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

                HStack {
                    Text("11月8日").frame(maxWidth: .infinity, alignment: .leading)
                    Text("RM0.00").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("RM57.00").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("-RM57.00").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 12, design: .rounded))
                .padding(10)

                Divider()

                HStack {
                    Text("11月7日").frame(maxWidth: .infinity, alignment: .leading)
                    Text("RM436.32").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("RM338.13").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("RM98.19").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 12, design: .rounded))
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(KapiTheme.divider, lineWidth: 1))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }
}
