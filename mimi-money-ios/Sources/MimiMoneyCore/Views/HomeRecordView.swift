import SwiftUI

public struct HomeRecordView: View {
    @ObservedObject public var store: MimiStore
    public var onOpenDrawer: () -> Void
    public var onSwitchToStats: () -> Void
    public var onOpenSearchOrCalendar: () -> Void
    public var onOpenRecordSheet: (Bool) -> Void // true = AI tab, false = Manual tab
    public var onSelectTransaction: (TransactionItem) -> Void
    public var onOpenBudgetManager: () -> Void
    public var onOpenAssetsManager: () -> Void
    public var onPickFromAlbum: () -> Void = {}
    public var onTakePhoto: () -> Void = {}
    public var onOpenImportExport: () -> Void = {}

    @State private var isAmountsHidden: Bool = false
    @State private var isAskPanelExpanded: Bool = false
    @State private var isCategoryBudgetExpanded: Bool = false
    @State private var isNetWorthExpanded: Bool = true
    @State private var showPageSwitcherMenu: Bool = false
    @State private var showLedgerSwitcherSheet: Bool = false

    public init(
        store: MimiStore,
        onOpenDrawer: @escaping () -> Void,
        onSwitchToStats: @escaping () -> Void,
        onOpenSearchOrCalendar: @escaping () -> Void,
        onOpenRecordSheet: @escaping (Bool) -> Void,
        onSelectTransaction: @escaping (TransactionItem) -> Void,
        onOpenBudgetManager: @escaping () -> Void,
        onOpenAssetsManager: @escaping () -> Void,
        onPickFromAlbum: @escaping () -> Void = {},
        onTakePhoto: @escaping () -> Void = {},
        onOpenImportExport: @escaping () -> Void = {}
    ) {
        self.store = store
        self.onOpenDrawer = onOpenDrawer
        self.onSwitchToStats = onSwitchToStats
        self.onOpenSearchOrCalendar = onOpenSearchOrCalendar
        self.onOpenRecordSheet = onOpenRecordSheet
        self.onSelectTransaction = onSelectTransaction
        self.onOpenBudgetManager = onOpenBudgetManager
        self.onOpenAssetsManager = onOpenAssetsManager
        self.onPickFromAlbum = onPickFromAlbum
        self.onTakePhoto = onTakePhoto
        self.onOpenImportExport = onOpenImportExport
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
            MimiTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topNavigationBar
                    .padding(.horizontal, MimiTheme.homeHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: MimiTheme.homeCardSpacing) {
                        monthlyBudgetCard
                        netWorthSummaryCard
                        transactionFeedSection
                    }
                    .padding(.horizontal, MimiTheme.homeHorizontalPadding)
                    .padding(.bottom, 110)
                }
            }

            floatingBottomBar
                .padding(.horizontal, MimiTheme.homeHorizontalPadding)
                .padding(.bottom, 12)
        }
        .sheet(isPresented: $showLedgerSwitcherSheet) {
            ledgerPickerSheet
                .presentationDetents([.height(260)])
        }
    }

    // MARK: - Top Navigation Bar (gold A)

    private var topNavigationBar: some View {
        HStack(spacing: 10) {
            Button(action: onOpenDrawer) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(MimiTheme.textPrimary)
                    .frame(width: 32, height: 36)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    // Already on 记录
                } label: {
                    Label("记录", systemImage: "checkmark")
                }
                Button {
                    onSwitchToStats()
                } label: {
                    Label("Mimi (统计与资产)", systemImage: "chart.pie")
                }
            } label: {
                HStack(spacing: 4) {
                    Text("记录")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(MimiTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MimiTheme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button(action: onOpenSearchOrCalendar) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(MimiTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)

            Button {
                showLedgerSwitcherSheet = true
            } label: {
                HStack(spacing: 4) {
                    Text(store.currentLedgerName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MimiTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 64, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MimiTheme.textSecondary)
                }
                .padding(.leading, 12)
                .padding(.trailing, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Monthly Budget Card (gold A)

    private var monthlyBudgetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Button(action: onOpenSearchOrCalendar) {
                    HStack(spacing: 4) {
                        Text("\(currentYear)年\(currentMonth)月")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(MimiTheme.textPrimary)
                }
                .buttonStyle(.plain)

                Button(action: onSwitchToStats) {
                    HStack(spacing: 2) {
                        Text("统计")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(MimiTheme.expenseBlue)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)
            }

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(MimiTheme.expenseBlue)
                            .frame(width: 3, height: 12)
                        Text("月预算剩余")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MimiTheme.textSecondary)
                    }

                    HStack(alignment: .center, spacing: 6) {
                        Button(action: onOpenBudgetManager) {
                            Text(isAmountsHidden ? "RM****" : MimiTheme.formatRM(monthlyRemaining))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(MimiTheme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .buttonStyle(.plain)

                        Button {
                            isAmountsHidden.toggle()
                        } label: {
                            Image(systemName: isAmountsHidden ? "eye.slash" : "eye")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(MimiTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }

                    budgetProgressBar

                    HStack(spacing: 8) {
                        Text(isAmountsHidden ? "已用****" : "已用\(MimiTheme.formatRM(monthlySpent))")
                            .font(.system(size: 12))
                            .foregroundColor(MimiTheme.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(isAmountsHidden ? "RM****" : MimiTheme.formatRM(store.monthlyBudgetTotal))
                            .font(.system(size: 12))
                            .foregroundColor(MimiTheme.textSecondary)
                            .lineLimit(1)
                    }
                }

                dailyAvailableRing
            }

            categoryBudgetSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: MimiTheme.cardCornerRadius, style: .continuous))
        .shadow(
            color: MimiTheme.homeCardShadow,
            radius: MimiTheme.homeCardShadowRadius,
            x: 0,
            y: MimiTheme.homeCardShadowY
        )
        .overlay(alignment: .topTrailing) {
            incomeExpensePill
                .padding(.trailing, 12)
                .offset(y: -12)
        }
        .padding(.top, 14)
    }

    /// Sits on the card's top-right corner, matching gold A. Opens the same calendar/search surface as the month chip.
    private var incomeExpensePill: some View {
        Button(action: onOpenSearchOrCalendar) {
            HStack(spacing: 3) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                Text("收支")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(MimiTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().stroke(Color(hex: 0xE5E7EB), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var budgetProgressBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let trackHeight: CGFloat = 5
            let fillWidth = min(width, max(trackHeight, width * CGFloat(spentRatio)))
            let badgeWidth: CGFloat = 36
            let badgeX = min(max(0, fillWidth - badgeWidth / 2), max(0, width - badgeWidth))
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: 0xE7EAF2))
                            .frame(height: trackHeight)
                        Capsule()
                            .fill(MimiTheme.expenseBlue)
                            .frame(width: fillWidth, height: trackHeight)
                    }
                }
                Text("\(spentPercentInt)%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(MimiTheme.expenseBlue)
                    .frame(width: badgeWidth, height: 16)
                    .background(Capsule().fill(Color(hex: 0xE8EEFF)))
                    .offset(x: badgeX, y: 0)
            }
        }
        .frame(height: MimiTheme.progressBarHeight)
    }

    private var dailyAvailableRing: some View {
        Button(action: onOpenBudgetManager) {
            ZStack {
                Circle()
                    .stroke(Color(hex: 0xEEF0F6), lineWidth: 8)
                    .frame(width: MimiTheme.dailyRingSize, height: MimiTheme.dailyRingSize)

                Circle()
                    .trim(from: 0, to: 0.92)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(hex: 0x4C6FFF),
                                Color(hex: 0xF0A04B),
                                Color(hex: 0x3DDC97),
                                Color(hex: 0xE85AD8),
                                Color(hex: 0x7A6CFF),
                                Color(hex: 0x4C6FFF)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: MimiTheme.dailyRingSize, height: MimiTheme.dailyRingSize)

                VStack(spacing: 1) {
                    Text("今日可用")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(MimiTheme.textSecondary)
                    Text(isAmountsHidden ? "****" : String(format: "%.2f", dailyAvailable))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(MimiTheme.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
            }
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    private var categoryBudgetSection: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    isCategoryBudgetExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: 0xD9E2FF), lineWidth: 3)
                            .frame(width: 16, height: 16)
                        Circle()
                            .trim(from: 0.08, to: 0.42)
                            .stroke(Color(hex: 0x7B93F7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 16, height: 16)
                            .rotationEffect(.degrees(-20))
                    }
                    .frame(width: 22, height: 22)
                    HStack(spacing: 6) {
                        Text("分类预算")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MimiTheme.textPrimary)
                        Text("共\(store.categoryBudgets.count)项")
                            .font(.system(size: 13))
                            .foregroundColor(MimiTheme.textMuted)
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 2) {
                        Text(isCategoryBudgetExpanded ? "收起" : "展开")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: isCategoryBudgetExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(MimiTheme.expenseBlue)
                }
            }
            .buttonStyle(.plain)

            if isCategoryBudgetExpanded {
                VStack(spacing: 10) {
                    ForEach(store.categoryBudgets) { item in
                        let spent = store.categorySpent(for: item.categoryName, year: currentYear, month: currentMonth)
                        let rem = item.monthlyLimit - spent
                        let ratio = item.monthlyLimit > 0 ? min(1.0, spent / item.monthlyLimit) : 0
                        let remLabel: String = {
                            if isAmountsHidden {
                                return rem >= 0 ? "剩余 ****" : "超支 ****"
                            }
                            return rem >= 0
                                ? "剩余 \(MimiTheme.formatRM(rem))"
                                : "超支 \(MimiTheme.formatRM(abs(rem)))"
                        }()
                        HStack(spacing: 10) {
                            MimiStickerIconView(
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
                                        .foregroundColor(MimiTheme.textPrimary)
                                    Spacer()
                                    Text(remLabel)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(rem >= 0 ? MimiTheme.textSecondary : MimiTheme.dangerRed)
                                }
                                GeometryReader { barGeo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color(hex: 0xF0F2F7))
                                            .frame(height: 6)
                                        Capsule()
                                            .fill(rem >= 0 ? MimiTheme.expenseBlue : MimiTheme.dangerRed)
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

    // MARK: - Net Worth Card (gold A)

    private var netWorthSummaryCard: some View {
        VStack(spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                Button(action: onOpenAssetsManager) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("净资产")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MimiTheme.textSecondary)
                        Text(isAmountsHidden ? "RM****" : MimiTheme.formatRM(store.netWorth))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(MimiTheme.textPrimary)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                if isNetWorthExpanded {
                    Button {
                        toggleNetWorthExpanded()
                    } label: {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("30天趋势")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(MimiTheme.expenseBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.92)))
                            HomeNetWorthSparkline()
                                .frame(width: 124, height: 32)
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }

            Button {
                toggleNetWorthExpanded()
            } label: {
                Image(systemName: isNetWorthExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MimiTheme.textMuted.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(
            RoundedRectangle(cornerRadius: MimiTheme.cardCornerRadius, style: .continuous)
                .fill(MimiTheme.netWorthCard)
        )
    }

    private func toggleNetWorthExpanded() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isNetWorthExpanded.toggle()
        }
    }

    // MARK: - Daily Grouped Transaction Feed (IMG_2240)

    private var transactionFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("记录明细")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
                Button(action: onOpenSearchOrCalendar) {
                    HStack(spacing: 3) {
                        Text("全部记录")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(MimiTheme.textSecondary)
                }
            }
            .padding(.top, 4)

            let groups = store.groupedTransactionsByDay()
            if groups.isEmpty {
                VStack(spacing: 8) {
                    Text("🐱")
                        .font(.system(size: 36))
                    Text("还没有账单记录，点击下方 + 或发送一句话记账吧")
                        .font(.system(size: 13))
                        .foregroundColor(MimiTheme.textMuted)
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
                    .foregroundColor(MimiTheme.textSecondary)
                Spacer()
                HStack(spacing: 10) {
                    if dayExpense > 0 {
                        Text("支 \(MimiTheme.formatRM(dayExpense))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MimiTheme.textSecondary)
                    }
                    if dayIncome > 0 {
                        Text("收 \(MimiTheme.formatRM(dayIncome))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MimiTheme.incomeOrange)
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
                        MimiStickerIconView(
                            iconName: item.iconName,
                            categoryName: item.categoryPath,
                            transactionType: item.type,
                            size: 38
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.categoryPath)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(MimiTheme.textPrimary)

                            HStack(spacing: 6) {
                                Text(item.accountName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(MimiTheme.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color(hex: 0xF2F4F8)))

                                if !item.note.isEmpty {
                                    Text(item.note)
                                        .font(.system(size: 12))
                                        .foregroundColor(MimiTheme.textMuted)
                                        .lineLimit(1)
                                }
                            }
                        }

                        Spacer()

                        Text(
                            item.type == .expense
                                ? "-\(MimiTheme.formatRM(item.amount))"
                                : "+\(MimiTheme.formatRM(item.amount))"
                        )
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(
                            item.type == .expense ? MimiTheme.expenseBlue : MimiTheme.incomeOrange
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

    // MARK: - Floating Bottom Bar (🐱 任何事情都能问我 [＋/✕] + 展开面板)

    private var floatingBottomBar: some View {
        VStack(spacing: 10) {
            if isAskPanelExpanded {
                AIAttachmentPanelView(
                    onPickFromAlbum: {
                        isAskPanelExpanded = false
                        onPickFromAlbum()
                    },
                    onTakePhoto: {
                        isAskPanelExpanded = false
                        onTakePhoto()
                    },
                    onOpenImportExport: {
                        isAskPanelExpanded = false
                        onOpenImportExport()
                    }
                )
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 8) {
                Button {
                    onOpenRecordSheet(true)
                } label: {
                    HStack(spacing: 8) {
                        Text("🐱")
                            .font(.system(size: 20))
                        Text("任何事情都能问我")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(MimiTheme.textSecondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        isAskPanelExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isAskPanelExpanded ? "xmark" : "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(MimiTheme.expenseBlue)
                                .shadow(color: MimiTheme.expenseBlue.opacity(0.35), radius: 8, x: 0, y: 3)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(height: 50)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            )
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
                            .foregroundColor(MimiTheme.textPrimary)
                        Spacer()
                        Text(ledger.currency.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(MimiTheme.textMuted)
                        if store.currentLedgerName == ledger.name {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(MimiTheme.expenseBlue)
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

/// Line sparkline shaped like gold A's 30-day net-worth trace.
private struct HomeNetWorthSparkline: View {
    private let samples: [CGFloat] = [
        0.46, 0.47, 0.48, 0.47, 0.49, 0.48, 0.50, 0.49,
        0.52, 0.70, 0.96, 0.74, 0.66, 0.72, 0.60, 0.58
    ]

    var body: some View {
        GeometryReader { geo in
            let points = samplePoints(in: geo.size)
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    MimiTheme.expenseBlue,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                if let last = points.last {
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(MimiTheme.expenseBlue, lineWidth: 2))
                        .frame(width: 8, height: 8)
                        .position(last)
                }
            }
        }
    }

    private func samplePoints(in size: CGSize) -> [CGPoint] {
        let count = max(samples.count - 1, 1)
        let inset: CGFloat = 5
        return samples.enumerated().map { index, value in
            let x = inset + (size.width - inset * 2) * CGFloat(index) / CGFloat(count)
            let y = size.height - (value * (size.height - 10)) - 5
            return CGPoint(x: x, y: y)
        }
    }
}
