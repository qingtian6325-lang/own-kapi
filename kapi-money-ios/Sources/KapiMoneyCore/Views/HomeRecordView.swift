import SwiftUI

public struct HomeRecordView: View {
    @ObservedObject public var store: KapiStore
    public var onOpenDrawer: () -> Void
    public var onSwitchToStats: () -> Void
    public var onOpenSearchOrCalendar: () -> Void
    public var onOpenRecordSheet: (Bool) -> Void // true = AI tab, false = Manual tab
    public var onSelectTransaction: (TransactionItem) -> Void
    public var onOpenBudgetManager: () -> Void
    public var onOpenAssetsManager: () -> Void

    @State private var isAmountsHidden: Bool = false
    @State private var isCategoryBudgetExpanded: Bool = false
    @State private var isNetWorthExpanded: Bool = true
    @State private var showPageSwitcherMenu: Bool = false
    @State private var showLedgerSwitcherSheet: Bool = false

    public init(
        store: KapiStore,
        onOpenDrawer: @escaping () -> Void,
        onSwitchToStats: @escaping () -> Void,
        onOpenSearchOrCalendar: @escaping () -> Void,
        onOpenRecordSheet: @escaping (Bool) -> Void,
        onSelectTransaction: @escaping (TransactionItem) -> Void,
        onOpenBudgetManager: @escaping () -> Void,
        onOpenAssetsManager: @escaping () -> Void
    ) {
        self.store = store
        self.onOpenDrawer = onOpenDrawer
        self.onSwitchToStats = onSwitchToStats
        self.onOpenSearchOrCalendar = onOpenSearchOrCalendar
        self.onOpenRecordSheet = onOpenRecordSheet
        self.onSelectTransaction = onSelectTransaction
        self.onOpenBudgetManager = onOpenBudgetManager
        self.onOpenAssetsManager = onOpenAssetsManager
    }

    private var currentYear: Int { 2026 }
    private var currentMonth: Int { 11 }

    private var monthlySpent: Double {
        store.monthlyExpenseTotal(year: currentYear, month: currentMonth)
    }

    private var monthlyRemaining: Double {
        store.monthlyBudgetRemaining(year: currentYear, month: currentMonth)
    }

    private var spentRatio: Double {
        guard store.monthlyBudgetTotal > 0 else { return 0 }
        return min(1.0, max(0.0, monthlySpent / store.monthlyBudgetTotal))
    }

    private var spentPercentInt: Int {
        Int((spentRatio * 100.0).rounded())
    }

    private var dailyAvailable: Double {
        DynamicBudgetEngine.calculateDailyBudget(
            monthlyBudget: store.monthlyBudgetTotal,
            spentBeforeToday: monthlySpent,
            remainingDaysIncludingToday: 21
        )
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            KapiTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topNavigationBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        monthlyBudgetCard
                        netWorthSummaryCard
                        transactionFeedSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
            }

            floatingBottomBar
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .sheet(isPresented: $showLedgerSwitcherSheet) {
            ledgerPickerSheet
                .presentationDetents([.height(260)])
        }
    }

    // MARK: - Top Navigation Bar (IMG_2240)

    private var topNavigationBar: some View {
        HStack(spacing: 12) {
            Button(action: onOpenDrawer) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(KapiTheme.textPrimary)
                    .frame(width: 34, height: 34)
            }

            Menu {
                Button {
                    // Already on 记录
                } label: {
                    Label("记录", systemImage: "checkmark")
                }
                Button {
                    onSwitchToStats()
                } label: {
                    Label("Kapi (统计与资产)", systemImage: "chart.pie")
                }
            } label: {
                HStack(spacing: 4) {
                    Text("记录")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(KapiTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(KapiTheme.textSecondary)
                }
            }

            Spacer()

            Button(action: onOpenSearchOrCalendar) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(KapiTheme.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white))
            }

            Button {
                showLedgerSwitcherSheet = true
            } label: {
                HStack(spacing: 5) {
                    Text(store.currentLedgerName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(KapiTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(KapiTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white))
            }
        }
    }

    // MARK: - Monthly Budget Card (IMG_2240 & IMG_2241)

    private var monthlyBudgetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("月预算剩余")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(KapiTheme.textSecondary)
                        Button {
                            isAmountsHidden.toggle()
                        } label: {
                            Image(systemName: isAmountsHidden ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                                .foregroundColor(KapiTheme.textMuted)
                        }
                    }

                    Button(action: onOpenBudgetManager) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(isAmountsHidden ? "RM****" : KapiTheme.formatRM(monthlyRemaining))
                                .font(.system(size: 27, weight: .bold, design: .rounded))
                                .foregroundColor(KapiTheme.textPrimary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KapiTheme.textMuted)
                        }
                    }
                    .buttonStyle(.plain)

                    // Horizontal progress bar with percentage (39%)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(hex: 0xEEF0F6))
                                .frame(height: 18)

                            Capsule()
                                .fill(KapiTheme.expenseBlue)
                                .frame(width: max(36, geo.size.width * CGFloat(spentRatio)), height: 18)

                            Text("\(spentPercentInt)%")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.leading, 8)
                        }
                    }
                    .frame(height: 18)
                    .padding(.top, 2)

                    HStack(spacing: 14) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(KapiTheme.expenseBlue)
                                .frame(width: 6, height: 6)
                            Text("总支出 \(isAmountsHidden ? "****" : KapiTheme.formatRM(monthlySpent))")
                                .font(.system(size: 11))
                                .foregroundColor(KapiTheme.textSecondary)
                        }

                        HStack(spacing: 4) {
                            Circle()
                                .fill(KapiTheme.incomeOrange)
                                .frame(width: 6, height: 6)
                            Text("总收入 \(isAmountsHidden ? "****" : KapiTheme.formatRM(store.monthlyIncomeTotal(year: currentYear, month: currentMonth)))")
                                .font(.system(size: 11))
                                .foregroundColor(KapiTheme.textSecondary)
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 16)

                // Right circular ring chart: 今日可用 92.26
                Button(action: onOpenBudgetManager) {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: 0xEEF0F6), lineWidth: 9)
                            .frame(width: 92, height: 92)

                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(
                                AngularGradient(
                                    colors: [KapiTheme.expenseBlue, Color(hex: 0x5B86F7), KapiTheme.incomeOrange],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 9, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 92, height: 92)

                        VStack(spacing: 2) {
                            Text("今日可用")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(KapiTheme.textSecondary)
                            Text(isAmountsHidden ? "****" : String(format: "%.2f", dailyAvailable))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(KapiTheme.textPrimary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Divider()
                .background(KapiTheme.divider)

            // Expandable Category Budget Bar (分类预算 共6项)
            VStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isCategoryBudgetExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("分类预算")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(KapiTheme.textPrimary)
                        Text("共\(store.categoryBudgets.count)项")
                            .font(.system(size: 12))
                            .foregroundColor(KapiTheme.textMuted)
                        Spacer()
                        Image(systemName: isCategoryBudgetExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(KapiTheme.textMuted)
                    }
                }
                .buttonStyle(.plain)

                if isCategoryBudgetExpanded {
                    VStack(spacing: 10) {
                        ForEach(store.categoryBudgets) { item in
                            let spent = store.categorySpent(for: item.categoryName, year: currentYear, month: currentMonth)
                            let rem = item.monthlyLimit - spent
                            let ratio = item.monthlyLimit > 0 ? min(1.0, spent / item.monthlyLimit) : 0
                            HStack(spacing: 10) {
                                KapiStickerIconView(
                                    iconName: item.iconName,
                                    categoryName: item.categoryName,
                                    transactionType: .expense,
                                    useFirstCharIcon: item.useFirstCharIcon,
                                    size: 30
                                )
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(item.categoryName)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(KapiTheme.textPrimary)
                                        Spacer()
                                        Text(rem >= 0 ? "剩余 \(KapiTheme.formatRM(rem))" : "超支 \(KapiTheme.formatRM(abs(rem)))")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(rem >= 0 ? KapiTheme.textSecondary : KapiTheme.dangerRed)
                                    }
                                    GeometryReader { barGeo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color(hex: 0xF0F2F7))
                                                .frame(height: 6)
                                            Capsule()
                                                .fill(rem >= 0 ? KapiTheme.expenseBlue : KapiTheme.dangerRed)
                                                .frame(width: barGeo.size.width * CGFloat(ratio), height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
    }

    // MARK: - Net Worth Card (IMG_2240 & IMG_2241)

    private var netWorthSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: onOpenAssetsManager) {
                    HStack(spacing: 6) {
                        Text("净资产")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(KapiTheme.textSecondary)
                        Text(isAmountsHidden ? "RM****" : KapiTheme.formatRM(store.netWorth))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(KapiTheme.textPrimary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(KapiTheme.textMuted)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isNetWorthExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("30天趋势")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(KapiTheme.expenseBlue)
                        Image(systemName: isNetWorthExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(KapiTheme.expenseBlue)
                    }
                }
                .buttonStyle(.plain)
            }

            if isNetWorthExpanded {
                HStack(alignment: .bottom) {
                    HStack(spacing: 14) {
                        Text("总资产 \(isAmountsHidden ? "****" : KapiTheme.formatRM(store.totalAssets))")
                            .font(.system(size: 12))
                            .foregroundColor(KapiTheme.textSecondary)
                        Text("总负债 \(isAmountsHidden ? "****" : KapiTheme.formatRM(store.totalLiabilities))")
                            .font(.system(size: 12))
                            .foregroundColor(KapiTheme.textSecondary)
                    }

                    Spacer()

                    // Mini 30-day sparkline
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach([0.38, 0.45, 0.42, 0.56, 0.62, 0.58, 0.78, 0.92], id: \.self) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(KapiTheme.expenseBlue.opacity(0.65))
                                .frame(width: 5, height: CGFloat(level * 26))
                        }
                    }
                }
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0xEAF1FF))
        )
    }

    // MARK: - Daily Grouped Transaction Feed (IMG_2240)

    private var transactionFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("记录明细")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)
                Spacer()
                Button(action: onOpenSearchOrCalendar) {
                    HStack(spacing: 3) {
                        Text("全部记录")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(KapiTheme.textSecondary)
                }
            }
            .padding(.top, 4)

            let groups = store.groupedTransactionsByDay()
            if groups.isEmpty {
                VStack(spacing: 8) {
                    Text("🦫")
                        .font(.system(size: 36))
                    Text("还没有账单记录，点击下方 + 或发送一句话记账吧")
                        .font(.system(size: 13))
                        .foregroundColor(KapiTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
            } else {
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    dayTransactionGroupCard(date: group.date, items: group.items)
                }
            }
        }
    }

    private func dayTransactionGroupCard(date: Date, items: [TransactionItem]) -> some View {
        let dayExpense = items.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
        let dayIncome = items.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }

        return VStack(spacing: 0) {
            HStack {
                Text(formatDayHeader(date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(KapiTheme.textSecondary)
                Spacer()
                HStack(spacing: 10) {
                    if dayExpense > 0 {
                        Text("支 \(KapiTheme.formatRM(dayExpense))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(KapiTheme.textSecondary)
                    }
                    if dayIncome > 0 {
                        Text("收 \(KapiTheme.formatRM(dayIncome))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(KapiTheme.incomeOrange)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(hex: 0xFAFBFD))

            ForEach(items) { item in
                Button {
                    onSelectTransaction(item)
                } label: {
                    HStack(spacing: 12) {
                        KapiStickerIconView(
                            iconName: item.iconName,
                            categoryName: item.categoryPath,
                            transactionType: item.type,
                            size: 38
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.categoryPath)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(KapiTheme.textPrimary)

                            HStack(spacing: 6) {
                                Text(item.accountName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(KapiTheme.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color(hex: 0xF2F4F8)))

                                if !item.note.isEmpty {
                                    Text(item.note)
                                        .font(.system(size: 12))
                                        .foregroundColor(KapiTheme.textMuted)
                                        .lineLimit(1)
                                }
                            }
                        }

                        Spacer()

                        Text(
                            item.type == .expense
                                ? "-\(KapiTheme.formatRM(item.amount))"
                                : "+\(KapiTheme.formatRM(item.amount))"
                        )
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(
                            item.type == .expense ? KapiTheme.expenseBlue : KapiTheme.incomeOrange
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if item.id != items.last?.id {
                    Divider()
                        .padding(.leading, 64)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func formatDayHeader(_ date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let weekday = cal.component(.weekday, from: date)
        let names = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let wName = (weekday >= 1 && weekday <= 7) ? names[weekday] : ""
        return "\(m)月\(d)日 (\(wName))"
    }

    // MARK: - Floating Bottom Bar (🦫 任何事情都能问我 + Blue +)

    private var floatingBottomBar: some View {
        HStack(spacing: 12) {
            Button {
                onOpenRecordSheet(true)
            } label: {
                HStack(spacing: 8) {
                    Text("🦫")
                        .font(.system(size: 20))
                    Text("任何事情都能问我")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KapiTheme.textSecondary)
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundColor(KapiTheme.expenseBlue)
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)

            Button {
                onOpenRecordSheet(false)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(KapiTheme.expenseBlue)
                            .shadow(color: KapiTheme.expenseBlue.opacity(0.35), radius: 10, x: 0, y: 4)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var ledgerPickerSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("切换账本")
                .font(.system(size: 17, weight: .bold))
                .padding(.top, 16)

            ForEach(store.ledgers) { ledger in
                Button {
                    store.currentLedgerName = ledger.name
                    showLedgerSwitcherSheet = false
                } label: {
                    HStack {
                        Text("📒")
                        Text(ledger.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(KapiTheme.textPrimary)
                        Spacer()
                        Text(ledger.currency.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(KapiTheme.textMuted)
                        if store.currentLedgerName == ledger.name {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(KapiTheme.expenseBlue)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xF5F6FA)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
