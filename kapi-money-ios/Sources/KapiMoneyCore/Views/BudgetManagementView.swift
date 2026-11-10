import SwiftUI

public struct BudgetManagementView: View {
    @ObservedObject public var store: KapiStore
    public var onDismiss: () -> Void

    @State private var showDynamicDailySheet: Bool = false
    @State private var showEditBudgetAlert: Bool = false
    @State private var budgetInputString: String = ""
    @State private var selectedDayKeyForCustomBudget: String?
    @State private var customDayBudgetInput: String = ""

    public init(store: KapiStore, onDismiss: @escaping () -> Void) {
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

    private var unbudgetedCategories: [CategoryGroup] {
        let budgetedNames = Set(store.categoryBudgets.map(\.categoryName))
        return store.expenseCategories.filter { !budgetedNames.contains($0.name) }
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
            .background(KapiTheme.background.ignoresSafeArea())
            .navigationTitle("预算管理")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(KapiTheme.textPrimary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Text("Main Ledger ⌄")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(KapiTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white))
                }
            }
            .sheet(isPresented: $showDynamicDailySheet) {
                dynamicDailyBudgetCalendarSheet
            }
        }
    }

    // MARK: - Top Monthly Overview +Ring Chart (IMG_2263)

    private var monthlySummaryTopCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("2026年11月 · 月预算剩余")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KapiTheme.textSecondary)

                    Text(KapiTheme.formatRM(monthlyRemaining))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(KapiTheme.textPrimary)

                    Text("总预算 \(KapiTheme.formatRM(store.monthlyBudgetTotal)) · 已用 \(KapiTheme.formatRM(monthlySpent))")
                        .font(.system(size: 12))
                        .foregroundColor(KapiTheme.textSecondary)
                }

                Spacer()

                Button {
                    showDynamicDailySheet = true
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: 0xEEF0F6), lineWidth: 9)
                            .frame(width: 86, height: 86)
                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(KapiTheme.expenseBlue, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 86, height: 86)
                        VStack(spacing: 2) {
                            Text("动态日预算")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(KapiTheme.expenseBlue)
                            Text(String(format: "%.2f", dailyAvailable))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(KapiTheme.textPrimary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                showDynamicDailySheet = true
            } label: {
                HStack {
                    Text("📅 查看动态日预算日历（长按日期可调整当日预算）")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KapiTheme.expenseBlue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(KapiTheme.expenseBlue)
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
                Text("已分类预算 (\(store.categoryBudgets.count))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)
                Spacer()
                Text("共 \(KapiTheme.formatRM(store.categoryBudgets.reduce(0) { $0 + $1.monthlyLimit }))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(KapiTheme.textSecondary)
            }

            ForEach(store.categoryBudgets) { item in
                let spent = store.categorySpent(for: item.categoryName, year: currentYear, month: currentMonth)
                let rem = item.monthlyLimit - spent
                let ratio = item.monthlyLimit > 0 ? min(1.0, spent / item.monthlyLimit) : 0

                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        KapiStickerIconView(
                            iconName: item.iconName,
                            categoryName: item.categoryName,
                            transactionType: .expense,
                            useFirstCharIcon: item.useFirstCharIcon,
                            size: 34
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.categoryName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(KapiTheme.textPrimary)
                            Text("预算 \(KapiTheme.formatRM(item.monthlyLimit)) · 已支 \(KapiTheme.formatRM(spent))")
                                .font(.system(size: 11))
                                .foregroundColor(KapiTheme.textMuted)
                        }

                        Spacer()

                        Text(rem >= 0 ? "剩余 \(KapiTheme.formatRM(rem))" : "超支 \(KapiTheme.formatRM(abs(rem)))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(rem >= 0 ? KapiTheme.textPrimary : KapiTheme.dangerRed)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(hex: 0xEEF0F6))
                                .frame(height: 8)
                            Capsule()
                                .fill(rem >= 0 ? KapiTheme.expenseBlue : KapiTheme.dangerRed)
                                .frame(width: geo.size.width * CGFloat(ratio), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - 未分类预算 (IMG_2264: Remaining categories with spent amounts)

    private var uncategorizedBudgetListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("未分类预算 (\(unbudgetedCategories.count))")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(KapiTheme.textPrimary)

            ForEach(unbudgetedCategories) { group in
                let spent = store.categorySpent(for: group.name, year: currentYear, month: currentMonth)
                HStack(spacing: 10) {
                    KapiStickerIconView(
                        iconName: group.displayBadgeToken,
                        categoryName: group.name,
                        transactionType: .expense,
                        useFirstCharIcon: group.useFirstCharIcon,
                        size: 32
                    )
                    Text(group.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KapiTheme.textPrimary)
                    Spacer()
                    Text("已用 \(KapiTheme.formatRM(spent))")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(KapiTheme.textSecondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - 动态日预算 Calendar Sheet (IMG_2266)

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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今日剩余可用")
                            .font(.system(size: 12))
                            .foregroundColor(KapiTheme.textSecondary)
                        Text(KapiTheme.formatRM(dailyAvailable - 57.00))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(KapiTheme.expenseBlue)
                        Text("今日预算 \(KapiTheme.formatRM(dailyAvailable)) · 今日已花费 RM57.00 · 结余会滚入后续日期")
                            .font(.system(size: 12))
                            .foregroundColor(KapiTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: 0xEAF1FF)))

                    if let editingKey = selectedDayKeyForCustomBudget {
                        HStack(spacing: 8) {
                            Text("调整 \(editingKey) 预算:")
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
                            .background(Capsule().fill(KapiTheme.expenseBlue))
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xE8F0FE)))
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                        ForEach(cells) { cell in
                            VStack(spacing: 2) {
                                Text("\(cell.day)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(cell.day == 8 ? .white : KapiTheme.textPrimary)
                                Text(cell.expense > 0 ? String(format: "-%.0f", cell.expense) : String(format: "%.0f", cell.dynamicAvailableBudget))
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundColor(cell.day == 8 ? .white.opacity(0.9) : (cell.expense > cell.dynamicAvailableBudget ? KapiTheme.dangerRed : KapiTheme.balanceGreen))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(cell.day == 8 ? KapiTheme.expenseBlue : Color.white)
                            )
                            .onLongPressGesture {
                                selectedDayKeyForCustomBudget = cell.id
                                customDayBudgetInput = String(format: "%.2f", cell.dynamicAvailableBudget)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(KapiTheme.background.ignoresSafeArea())
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
}
