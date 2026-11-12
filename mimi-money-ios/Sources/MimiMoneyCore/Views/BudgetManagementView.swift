import SwiftUI

public struct BudgetManagementView: View {
    @ObservedObject public var store: MimiStore
    public var onDismiss: () -> Void

    @State private var showDynamicDailySheet: Bool = false
    private enum ActiveBudgetSheetType: Identifiable {
        case editTotal
        case editCategory(CategoryBudgetItem)
        case addCategory(CategoryGroup)
        case selectNewCategory

        var id: String {
            switch self {
            case .editTotal: return "total"
            case .editCategory(let c): return "edit_\(c.categoryName)"
            case .addCategory(let g): return "add_\(g.name)"
            case .selectNewCategory: return "select_new"
            }
        }
    }

    @State private var activeSheetType: ActiveBudgetSheetType? = nil
    @State private var totalBudgetInput: String = ""
    @State private var categoryBudgetInput: String = ""
    @State private var newCategoryBudgetInput: String = ""
    @State private var selectedDayKeyForCustomBudget: String?
    @State private var customDayBudgetInput: String = ""
    @State private var categoryBudgetsExpanded: Bool = true

    public init(store: MimiStore, onDismiss: @escaping () -> Void) {
        self.store = store
        self.onDismiss = onDismiss
    }

    private var currentYear: Int { 2026 }
    private var currentMonth: Int { 11 }

    private var monthlySpent: Double {
        store.monthlyExpenseTotal(year: currentYear, month: currentMonth)
    }

    private var monthlyRemaining: Double {
        store.monthlyBudgetRemaining(year: currentYear, month: currentMonth)
    }

    private var dailyAvailable: Double {
        DynamicBudgetEngine.calculateDailyBudget(
            monthlyBudget: store.monthlyBudgetTotal,
            spentBeforeToday: monthlySpent,
            remainingDaysIncludingToday: 21
        )
    }

    private var todaySpent: Double {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let todayComps = cal.dateComponents([.year, .month, .day], from: now)
        let targetYear = (todayComps.year == currentYear && todayComps.month == currentMonth) ? (todayComps.year ?? currentYear) : currentYear
        let targetMonth = (todayComps.year == currentYear && todayComps.month == currentMonth) ? (todayComps.month ?? currentMonth) : currentMonth
        let targetDay = (todayComps.year == currentYear && todayComps.month == currentMonth) ? (todayComps.day ?? 8) : 8

        return store.transactions
            .filter { tx in
                guard tx.type == .expense && tx.includeInStats else { return false }
                let comps = cal.dateComponents([.year, .month, .day], from: tx.date)
                return comps.year == targetYear && comps.month == targetMonth && comps.day == targetDay
            }
            .reduce(0.0) { $0 + $1.amount }
    }

    private var todayRemainingAvailable: Double {
        max(0.0, dailyAvailable - todaySpent)
    }

    private var unbudgetedCategories: [CategoryGroup] {
        let budgetedNames = Set(store.categoryBudgets.map(\.categoryName))
        return store.expenseCategories.filter { !budgetedNames.contains($0.name) }
    }

    /// Pool left for uncategorized spend (gold: 未分类预算 已用 | 限额).
    private var categorizedBudgetTotal: Double {
        store.categoryBudgets.reduce(0.0) { $0 + $1.monthlyLimit }
    }

    private var uncategorizedBudgetLimit: Double {
        max(0.0, store.monthlyBudgetTotal - categorizedBudgetTotal)
    }

    private var categorizedSpentTotal: Double {
        store.categoryBudgets.reduce(0.0) { partial, item in
            partial + store.categorySpent(for: item.categoryName, year: currentYear, month: currentMonth)
        }
    }

    private var uncategorizedSpentTotal: Double {
        max(0.0, monthlySpent - categorizedSpentTotal)
    }

    public var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    monthlySummaryTopCard
                    categorizedBudgetListCard
                    uncategorizedBudgetListCard
                }
                .padding(16)
            }
            .background(MimiTheme.background.ignoresSafeArea())
            .navigationTitle("预算管理")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(MimiTheme.textPrimary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Text("Main Ledger ⌄")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(MimiTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white))
                }
            }
            .sheet(isPresented: $showDynamicDailySheet) {
                dynamicDailyBudgetCalendarSheet
            }
            .sheet(item: $activeSheetType) { sheetType in
                budgetModalSheet(for: sheetType)
            }
        }
    }

    @ViewBuilder
    private func budgetModalSheet(for sheetType: ActiveBudgetSheetType) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                switch sheetType {
                case .editTotal:
                    Text("设置月度总预算")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(MimiTheme.textPrimary)

                    Text("当前总预算为 \(MimiTheme.formatRM(store.monthlyBudgetTotal))。设置后将实时影响当月结余与日预算。")
                        .font(.system(size: 13))
                        .foregroundColor(MimiTheme.textSecondary)

                    HStack(spacing: 6) {
                        Text("RM")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(MimiTheme.textPrimary)
                        TextField("0.00", text: $totalBudgetInput)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF5F6FA)))

                    Button {
                        if let val = Double(totalBudgetInput), val >= 0 {
                            store.updateMonthlyBudget(val)
                        }
                        activeSheetType = nil
                    } label: {
                        Text("保存总预算")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.expenseBlue))
                    }
                    .buttonStyle(.plain)

                case .editCategory(let item):
                    HStack(spacing: 10) {
                        MimiStickerIconView(
                            iconName: item.iconName,
                            categoryName: item.categoryName,
                            transactionType: .expense,
                            useFirstCharIcon: item.useFirstCharIcon,
                            size: 34
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.categoryName)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(MimiTheme.textPrimary)
                            Text("修改此分类月度支出上限")
                                .font(.system(size: 12))
                                .foregroundColor(MimiTheme.textSecondary)
                        }
                    }

                    HStack(spacing: 6) {
                        Text("RM")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(MimiTheme.textPrimary)
                        TextField("0.00", text: $categoryBudgetInput)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF5F6FA)))

                    HStack(spacing: 10) {
                        Button {
                            store.removeCategoryBudget(categoryName: item.categoryName)
                            activeSheetType = nil
                        } label: {
                            Text("删除分类预算")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(MimiTheme.dangerRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xFEECEC)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            if let val = Double(categoryBudgetInput), val >= 0 {
                                store.setCategoryBudget(categoryName: item.categoryName, monthlyLimit: val, iconName: item.iconName)
                            }
                            activeSheetType = nil
                        } label: {
                            Text("保存修改")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.expenseBlue))
                        }
                        .buttonStyle(.plain)
                    }

                case .addCategory(let grp):
                    HStack(spacing: 10) {
                        MimiStickerIconView(
                            iconName: grp.displayBadgeToken,
                            categoryName: grp.name,
                            transactionType: .expense,
                            useFirstCharIcon: grp.useFirstCharIcon,
                            size: 34
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("为「\(grp.name)」添加预算")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(MimiTheme.textPrimary)
                            Text("设定该分类每月支出上限")
                                .font(.system(size: 12))
                                .foregroundColor(MimiTheme.textSecondary)
                        }
                    }

                    HStack(spacing: 6) {
                        Text("RM")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(MimiTheme.textPrimary)
                        TextField("0.00", text: $newCategoryBudgetInput)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF5F6FA)))

                    Button {
                        if let val = Double(newCategoryBudgetInput), val > 0 {
                            store.setCategoryBudget(categoryName: grp.name, monthlyLimit: val, iconName: grp.displayBadgeToken)
                        }
                        activeSheetType = nil
                    } label: {
                        Text("确定添加分类预算")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.expenseBlue))
                    }
                    .buttonStyle(.plain)

                case .selectNewCategory:
                    Text("选择要增加预算的分类")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(MimiTheme.textPrimary)

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(unbudgetedCategories) { grp in
                                Button {
                                    newCategoryBudgetInput = "200.00"
                                    activeSheetType = .addCategory(grp)
                                } label: {
                                    HStack(spacing: 12) {
                                        MimiStickerIconView(
                                            iconName: grp.displayBadgeToken,
                                            categoryName: grp.name,
                                            transactionType: .expense,
                                            useFirstCharIcon: grp.useFirstCharIcon,
                                            size: 32
                                        )
                                        Text(grp.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(MimiTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(MimiTheme.expenseBlue)
                                    }
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF5F6FA)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { activeSheetType = nil }
                }
            }
        }
        .presentationDetents([.height(340)])
    }

    // MARK: - Top Monthly Overview +Ring Chart (IMG_2263)

    private var budgetUsedRatio: Double {
        let total = max(store.monthlyBudgetTotal, 0.0001)
        return min(1.0, max(0.0, monthlySpent / total))
    }

    private var monthlySummaryTopCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("2026年11月")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(MimiTheme.textSecondary)

                    Text("月预算剩余")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(MimiTheme.textSecondary)

                    Text(MimiTheme.formatRM(monthlyRemaining))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(MimiTheme.textPrimary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: 0xEEF0F6)).frame(height: MimiTheme.progressBarHeight)
                            Capsule()
                                .fill(MimiTheme.expenseBlue)
                                .frame(width: max(8, geo.size.width * CGFloat(budgetUsedRatio)), height: MimiTheme.progressBarHeight)
                            Text("\(Int((budgetUsedRatio * 100).rounded()))%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.leading, 8)
                        }
                    }
                    .frame(height: MimiTheme.progressBarHeight)

                    HStack {
                        Text("已用 \(MimiTheme.formatRM(monthlySpent))")
                            .font(.system(size: 12))
                            .foregroundColor(MimiTheme.textSecondary)
                        Spacer()
                        Button {
                            totalBudgetInput = String(format: "%.2f", store.monthlyBudgetTotal)
                            activeSheetType = .editTotal
                        } label: {
                            Text(MimiTheme.formatRM(store.monthlyBudgetTotal))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(MimiTheme.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 12)

                Button {
                    showDynamicDailySheet = true
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: 0xEEF0F6), lineWidth: 9)
                            .frame(width: 86, height: 86)
                        Circle()
                            .trim(from: 0, to: CGFloat(min(1, todayRemainingAvailable / max(dailyAvailable, 0.0001))))
                            .stroke(MimiTheme.expenseBlue, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 86, height: 86)
                        VStack(spacing: 2) {
                            Text("今日可用")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(MimiTheme.expenseBlue)
                            Text(String(format: "%.2f", todayRemainingAvailable))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(MimiTheme.textPrimary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                showDynamicDailySheet = true
            } label: {
                HStack {
                    Text("查看动态日预算日历")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(MimiTheme.expenseBlue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(MimiTheme.expenseBlue)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xE8F0FE)))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - 已分类预算 (IMG_2263: 6 configured categories)

    private var categorizedBudgetListCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("已分类预算")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
                Text(MimiTheme.formatRM(categorizedBudgetTotal))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(MimiTheme.textPrimary)
                Button {
                    activeSheetType = .selectNewCategory
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(MimiTheme.expenseBlue)
                }
                .buttonStyle(.plain)
            }

            if categoryBudgetsExpanded {
                ForEach(store.categoryBudgets) { item in
                    let spent = store.categorySpent(for: item.categoryName, year: currentYear, month: currentMonth)
                    let rem = item.monthlyLimit - spent
                    let ratio = item.monthlyLimit > 0 ? min(1.0, spent / item.monthlyLimit) : 0

                    Button {
                        categoryBudgetInput = String(format: "%.2f", item.monthlyLimit)
                        activeSheetType = .editCategory(item)
                    } label: {
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                MimiStickerIconView(
                                    iconName: item.iconName,
                                    categoryName: item.categoryName,
                                    transactionType: .expense,
                                    useFirstCharIcon: item.useFirstCharIcon,
                                    size: 34
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.categoryName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(MimiTheme.textPrimary)
                                    Text("已用\(MimiTheme.formatRM(spent)) | \(MimiTheme.formatRM(item.monthlyLimit))")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(MimiTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(MimiTheme.textMuted)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(hex: 0xEEF0F6))
                                        .frame(height: 8)
                                    Capsule()
                                        .fill(rem >= 0 ? MimiTheme.expenseBlue : MimiTheme.dangerRed)
                                        .frame(width: geo.size.width * CGFloat(ratio), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    categoryBudgetsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Spacer()
                    Text(categoryBudgetsExpanded ? "收起" : "展开")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: categoryBudgetsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                }
                .foregroundColor(MimiTheme.textSecondary)
                .padding(.top, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - 未分类预算 (IMG_2264: Remaining categories with spent amounts)

    private var uncategorizedBudgetListCard: some View {
        let overspent = uncategorizedSpentTotal > uncategorizedBudgetLimit + 0.009

        return VStack(alignment: .leading, spacing: 12) {
            // Gold: single pool card 未分类预算 已用 | 限额 (highlight when over)
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: 0xFFE8CC))
                        .frame(width: 40, height: 40)
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(MimiTheme.incomeOrange)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("未分类预算")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MimiTheme.textPrimary)
                    Text("已用\(MimiTheme.formatRM(uncategorizedSpentTotal)) | \(MimiTheme.formatRM(uncategorizedBudgetLimit))")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(overspent ? MimiTheme.dangerRed : MimiTheme.textSecondary)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(overspent ? Color(hex: 0xEAF1FF) : Color(hex: 0xF7F8FA))
            )

            if !unbudgetedCategories.isEmpty {
                Text("可设预算的分类")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(MimiTheme.textMuted)

                ForEach(unbudgetedCategories.prefix(8)) { group in
                    let spent = store.categorySpent(for: group.name, year: currentYear, month: currentMonth)
                    HStack(spacing: 10) {
                        MimiStickerIconView(
                            iconName: group.displayBadgeToken,
                            categoryName: group.name,
                            transactionType: .expense,
                            useFirstCharIcon: group.useFirstCharIcon,
                            size: 32
                        )
                        Text(group.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(MimiTheme.textPrimary)
                        Spacer()
                        Text("已用 \(MimiTheme.formatRM(spent))")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(MimiTheme.textSecondary)

                        Button {
                            newCategoryBudgetInput = "200.00"
                            activeSheetType = .addCategory(group)
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "plus.circle.fill")
                                Text("设预算")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MimiTheme.expenseBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(hex: 0xE8F0FE)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - 动态日预算 Calendar Sheet (gold)

    private var dynamicDailyLeadingBlanks: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday-first per gold budget calendar
        var comps = DateComponents()
        comps.year = currentYear
        comps.month = currentMonth
        comps.day = 1
        guard let first = cal.date(from: comps) else { return 0 }
        let weekday = cal.component(.weekday, from: first) // 1=Sun
        return (weekday + 5) % 7
    }

    private var dynamicDailyBudgetCalendarSheet: some View {
        let cells = DynamicBudgetEngine.buildMonthDayCells(
            year: currentYear,
            month: currentMonth,
            ledger: store.currentLedger,
            transactions: store.transactions
        )

        return NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("动态日预算")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(MimiTheme.textPrimary)
                        Spacer()
                        Button {
                            // Focus edit on today cell when available
                            if let today = cells.first(where: { $0.isToday }) {
                                selectedDayKeyForCustomBudget = today.id
                                customDayBudgetInput = String(format: "%.2f", today.dynamicAvailableBudget)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("日预算设置")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(MimiTheme.expenseBlue)
                        }
                        .buttonStyle(.plain)
                    }

                    if let editingKey = selectedDayKeyForCustomBudget {
                        HStack(spacing: 8) {
                            Text("调整 \(editingKey)")
                                .font(.system(size: 12, weight: .semibold))
                            TextField("输入金额", text: $customDayBudgetInput)
                                .font(.system(size: 13))
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                            Button("保存") {
                                if let val = Double(customDayBudgetInput) {
                                    store.setCustomDailyBudget(dateKey: editingKey, amount: val)
                                }
                                selectedDayKeyForCustomBudget = nil
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(MimiTheme.expenseBlue))
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xE8F0FE)))
                    }

                    VStack(spacing: 8) {
                        HStack(spacing: 0) {
                            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { w in
                                Text(w)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(MimiTheme.textMuted)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                            ForEach(0..<dynamicDailyLeadingBlanks, id: \.self) { _ in
                                Color.clear.frame(height: 58)
                            }
                            ForEach(cells) { cell in
                                dynamicDayCell(cell)
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                }
                .padding(16)
            }
            .background(MimiTheme.background.ignoresSafeArea())
            .navigationTitle("动态日预算")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showDynamicDailySheet = false }
                }
            }
        }
    }

    private func dynamicDayCell(_ cell: CalendarDaySummary) -> some View {
        return VStack(spacing: 2) {
            Text(cell.isToday ? "今" : "\(cell.day)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(cell.isToday ? .white : MimiTheme.textPrimary)

            if cell.isToday {
                Text(MimiTheme.formatRM(todaySpent))
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(MimiTheme.formatRM(todayRemainingAvailable))
                    .font(.system(size: 8, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else if cell.isPast {
                Text(String(format: "-RM%.2f", cell.expense))
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundColor(MimiTheme.expenseBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text(MimiTheme.formatRM(cell.dynamicAvailableBudget))
                    .font(.system(size: 8, design: .rounded))
                    .foregroundColor(MimiTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cell.isToday ? MimiTheme.expenseBlue : Color(hex: 0xF8F9FC))
        )
        .onLongPressGesture {
            selectedDayKeyForCustomBudget = cell.id
            customDayBudgetInput = String(format: "%.2f", cell.dynamicAvailableBudget)
        }
    }
}
