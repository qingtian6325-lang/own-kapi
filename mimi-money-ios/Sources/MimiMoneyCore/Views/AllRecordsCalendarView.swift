import SwiftUI

public struct AllRecordsCalendarView: View {
    @ObservedObject public var store: MimiStore
    public var onDismiss: () -> Void
    public var onSelectTransaction: (TransactionItem) -> Void
    public var onOpenStats: () -> Void
    public var onOpenAsk: () -> Void
    public var onOpenRecord: () -> Void

    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var selectedDay: Int
    @State private var filterMode: String = "收支" // "收支" | "支出" | "收入"
    @State private var searchQuery: String = ""
    @State private var showSearchField: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        store: MimiStore,
        onDismiss: @escaping () -> Void,
        onSelectTransaction: @escaping (TransactionItem) -> Void,
        onOpenStats: @escaping () -> Void = {},
        onOpenAsk: @escaping () -> Void = {},
        onOpenRecord: @escaping () -> Void = {}
    ) {
        self.store = store
        self.onDismiss = onDismiss
        self.onSelectTransaction = onSelectTransaction
        self.onOpenStats = onOpenStats
        self.onOpenAsk = onOpenAsk
        self.onOpenRecord = onOpenRecord
        let now = Date()
        let cal = Calendar.current
        _selectedYear = State(initialValue: cal.component(.year, from: now))
        _selectedMonth = State(initialValue: cal.component(.month, from: now))
        _selectedDay = State(initialValue: cal.component(.day, from: now))
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday-first to match gold C0
        return cal
    }

    private var leadingBlankCount: Int {
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = selectedMonth
        comps.day = 1
        guard let firstDate = calendar.date(from: comps) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDate) // 1 = Sun ... 7 = Sat
        return weekday - 1
    }

    /// Expense-mode daily average: month expense / days elapsed before「今」(C2: 1262.52/9).
    private var dailyAverageExpense: Double {
        let todayDay = monthDayCells.first(where: { $0.isToday })?.day
        let divisor: Int
        if let todayDay {
            divisor = max(todayDay - 1, 1)
        } else if let range = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) ?? Date()) {
            divisor = range.count
        } else {
            divisor = 30
        }
        return monthlyExpenseTotal / Double(divisor)
    }

    private var monthDayCells: [CalendarDaySummary] {
        DynamicBudgetEngine.buildMonthDayCells(
            year: selectedYear,
            month: selectedMonth,
            transactions: store.transactions
        )
    }

    private var monthlyExpenseTotal: Double {
        store.monthlyExpenseTotal(year: selectedYear, month: selectedMonth)
    }

    private var monthlyIncomeTotal: Double {
        store.monthlyIncomeTotal(year: selectedYear, month: selectedMonth)
    }

    private var selectedDateTransactions: [TransactionItem] {
        store.transactions.filter { tx in
            let comps = calendar.dateComponents([.year, .month, .day], from: tx.date)
            guard comps.year == selectedYear && comps.month == selectedMonth && comps.day == selectedDay else {
                return false
            }
            if filterMode == "支出" && tx.type != .expense { return false }
            if filterMode == "收入" && tx.type != .income { return false }
            if !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                return tx.categoryPath.lowercased().contains(q)
                    || tx.note.lowercased().contains(q)
                    || tx.accountName.lowercased().contains(q)
            }
            return true
        }
    }

    private var selectedDayWeekdayString: String {
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = selectedMonth
        comps.day = selectedDay
        guard let date = calendar.date(from: comps) else { return "周日" }
        let weekday = calendar.component(.weekday, from: date)
        let map = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return (weekday >= 1 && weekday <= 7) ? map[weekday] : "周日"
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        subHeaderMonthBar
                        monthlySummaryBar

                        if showSearchField {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(MimiTheme.textMuted)
                                TextField("搜索当日分类、备注、账户...", text: $searchQuery)
                                    .mimiFont(14)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.cardBackground))
                        }

                        calendarCard
                        selectedDayDetailSection
                    }
                    .padding(.horizontal, MimiTheme.calendarHorizontalPadding)
                    .padding(.top, 6)
                    .padding(.bottom, 90)
                }
                .background(MimiTheme.background.ignoresSafeArea())

                floatingBottomBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .navigationTitle("全部记录")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .mimiFont(16, weight: .semibold)
                            .foregroundColor(MimiTheme.textPrimary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        withAnimation(MimiMotion.quick(reduceMotion: reduceMotion)) { showSearchField.toggle() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .mimiFont(14, weight: .semibold)
                            .foregroundColor(MimiTheme.textPrimary)
                    }
                }
            }
        }
        .mimiEdgeSwipeBack(onBack: onDismiss)
    }

    // MARK: - SubHeader Month Bar (2026年11月 > | 回今天 | 收支 v)

    private var subHeaderMonthBar: some View {
        HStack(spacing: 8) {
            Menu {
                let thisYear = Calendar.current.component(.year, from: Date())
                ForEach((thisYear - 2)...(thisYear + 1), id: \.self) { y in
                    Button("\(y)年") { selectedYear = y }
                }
                Divider()
                ForEach(1...12, id: \.self) { m in
                    Button(String(format: "%d月", m)) {
                        selectedMonth = m
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(String(format: "%d年%d月", selectedYear, selectedMonth))
                        .mimiFont(17, weight: .bold, design: .rounded)
                        .foregroundColor(MimiTheme.textPrimary)
                    Image(systemName: "chevron.right")
                        .mimiFont(11, weight: .bold)
                        .foregroundColor(MimiTheme.textMuted)
                }
            }

            Button {
                let now = Date()
                selectedYear = Calendar.current.component(.year, from: now)
                selectedMonth = Calendar.current.component(.month, from: now)
                selectedDay = Calendar.current.component(.day, from: now)
            } label: {
                Text("回今天")
                    .mimiFont(11, weight: .semibold)
                    .foregroundColor(MimiTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(MimiTheme.surfaceMuted))
            }
            .mimiPressable()
            .accessibilityLabel("回今天")

            Spacer()

            Menu {
                Button("收支") { filterMode = "收支" }
                Button("支出") { filterMode = "支出" }
                Button("收入") { filterMode = "收入" }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "creditcard")
                        .mimiFont(11)
                    Text(filterMode)
                        .mimiFont(12, weight: .semibold)
                    Image(systemName: "chevron.down")
                        .mimiFont(9, weight: .bold)
                }
                .foregroundColor(MimiTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(MimiTheme.cardBackground))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Monthly Summary Bar (月支出 RM1,262.52 | 月收入 RM1,196.71 收支分析 >)

    private var monthlySummaryBar: some View {
        HStack {
            HStack(spacing: 8) {
                Text("月支出")
                    .mimiFont(11)
                    .foregroundColor(MimiTheme.textSecondary)
                Text(MimiTheme.formatRM(monthlyExpenseTotal))
                    .mimiFont(13, weight: .bold, design: .rounded)
                    .foregroundColor(MimiTheme.expenseBlue)

                Text("|")
                    .mimiFont(11)
                    .foregroundColor(Color.gray.opacity(0.3))

                if filterMode == "支出" {
                    Text("日均支出")
                        .mimiFont(11)
                        .foregroundColor(MimiTheme.textSecondary)
                    Text(MimiTheme.formatRM(dailyAverageExpense))
                        .mimiFont(13, weight: .bold, design: .rounded)
                        .foregroundColor(MimiTheme.expenseBlue)
                } else {
                    Text("月收入")
                        .mimiFont(11)
                        .foregroundColor(MimiTheme.textSecondary)
                    Text(MimiTheme.formatRM(monthlyIncomeTotal))
                        .mimiFont(13, weight: .bold, design: .rounded)
                        .foregroundColor(MimiTheme.incomeOrange)
                }
            }

            Spacer()

            Button {
                onOpenStats()
            } label: {
                HStack(spacing: 2) {
                    Text(filterMode == "支出" ? "支出分析" : "收支分析")
                        .mimiFont(11, weight: .medium)
                    Image(systemName: "chevron.right")
                        .mimiFont(9, weight: .bold)
                }
                .foregroundColor(MimiTheme.textMuted)
            }
            .mimiPressable()
            .accessibilityLabel(filterMode == "支出" ? "支出分析" : "收支分析")
            .accessibilityHint("打开图表统计")
        }
        .padding(.vertical, 2)
    }

    // MARK: - Calendar Card (一 二 三 四 五 六 日 + Heatmap Colors)

    private var calendarCard: some View {
        VStack(spacing: 8) {
            // Weekday Header: 日 一 二 三 四 五 六 (Sunday-first, gold C0)
            HStack(spacing: 0) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .mimiFont(12, weight: .medium)
                        .foregroundColor(MimiTheme.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                // Leading blank cells
                ForEach(0..<leadingBlankCount, id: \.self) { _ in
                    Color.clear
                        .frame(height: MimiTheme.calendarDayCellHeight)
                }

                // Days in Month
                ForEach(monthDayCells) { cell in
                    let isSelected = cell.day == selectedDay
                    Button {
                        selectedDay = cell.day
                    } label: {
                        dayCellView(for: cell, isSelected: isSelected)
                    }
                    .mimiPressable()
                }
            }
            .padding(.vertical, 4)

            // Heatmap Legend: 收入多 🟧 🟨 ⬜ 🟦 🟦 支出多
            HStack(spacing: 6) {
                Text("收入多")
                    .mimiFont(10)
                    .foregroundColor(MimiTheme.textMuted)

                RoundedRectangle(cornerRadius: 2).fill(MimiTheme.heatmapIncome2).frame(width: 12, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(MimiTheme.heatmapIncome1).frame(width: 12, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(MimiTheme.fillSubtle).frame(width: 12, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(MimiTheme.heatmapExpense1).frame(width: 12, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(MimiTheme.heatmapExpense2).frame(width: 12, height: 10)

                Text("支出多")
                    .mimiFont(10)
                    .foregroundColor(MimiTheme.textMuted)
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: MimiTheme.calendarCardCorner, style: .continuous).fill(MimiTheme.cardBackground))
    }

    private func dayCellView(for cell: CalendarDaySummary, isSelected: Bool) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 2) {
                Text(cell.isToday ? "今" : "\(cell.day)")
                    .mimiFont(12, weight: cell.isToday || isSelected ? .bold : .semibold, design: .rounded)
                    .foregroundColor(MimiTheme.textPrimary)

                if cell.isHighestExpenseDay {
                    Image(systemName: "circle.fill")
                        .mimiFont(7)
                        .foregroundColor(MimiTheme.vipGold)
                        .overlay(
                            Text("¥")
                                .mimiFont(5, weight: .bold)
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)

            Spacer(minLength: 0)

            if cell.expense > 0 && filterMode != "收入" {
                Text(String(format: "-%.2f", cell.expense))
                    .mimiFont(8, weight: .bold, design: .rounded)
                    .foregroundColor(MimiTheme.expenseDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if cell.income > 0 && filterMode != "支出" {
                Text(String(format: "+%.2f", cell.income))
                    .mimiFont(8, weight: .bold, design: .rounded)
                    .foregroundColor(MimiTheme.incomeDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: MimiTheme.calendarDayCellHeight)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cellBackgroundColor(for: cell, isSelected: isSelected))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? MimiTheme.expenseBlue : Color.clear, lineWidth: 2)
        )
    }

    private func cellBackgroundColor(for cell: CalendarDaySummary, isSelected: Bool) -> Color {
        if isSelected {
            return MimiTheme.selectionSoft
        }
        // Highest spend or > RM500 -> deep blue
        if cell.isHighestExpenseDay || cell.expense >= 500 {
            return MimiTheme.heatmapExpense2
        }
        // Income dominant day
        if cell.income >= 500 {
            return MimiTheme.heatmapIncome2
        } else if cell.income > 0 && cell.income > cell.expense {
            return MimiTheme.heatmapIncome1
        }
        // Moderate expense
        if cell.expense >= 30 {
            return MimiTheme.heatmapExpense1
        } else if cell.expense > 0 {
            return MimiTheme.selectionSoftAlt
        }
        return MimiTheme.surfaceQuiet
    }

    // MARK: - Selected Day Detail Section (11月8日 (周日) 支 RM44.68 | 收 RM0.00)

    private var selectedDayDetailSection: some View {
        let dayExpense = selectedDateTransactions.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
        let dayIncome = selectedDateTransactions.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(format: "%d月%d日 (%@)", selectedMonth, selectedDay, selectedDayWeekdayString))
                    .mimiFont(13, weight: .bold)
                    .foregroundColor(MimiTheme.textPrimary)

                Spacer()

                HStack(spacing: 8) {
                    Text("支 \(MimiTheme.formatRM(dayExpense))")
                        .mimiFont(12, weight: .bold, design: .rounded)
                        .foregroundColor(MimiTheme.textPrimary)
                    Text("|")
                        .foregroundColor(Color.gray.opacity(0.3))
                    Text("收 \(MimiTheme.formatRM(dayIncome))")
                        .mimiFont(12, weight: .bold, design: .rounded)
                        .foregroundColor(MimiTheme.textSecondary)
                }
            }
            .padding(.horizontal, 2)

            if selectedDateTransactions.isEmpty {
                VStack(spacing: 6) {
                    Text("当日暂无记账记录")
                        .mimiFont(13)
                        .foregroundColor(MimiTheme.textMuted)
                    Text("点击右下角「+」快速补记一笔")
                        .mimiFont(11)
                        .foregroundColor(MimiTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(RoundedRectangle(cornerRadius: 16).fill(MimiTheme.cardBackground))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(selectedDateTransactions.enumerated()), id: \.element.id) { index, item in
                        Button {
                            onSelectTransaction(item)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(MimiTheme.selectionSoftAlt)
                                        .frame(width: 40, height: 40)
                                    Text(item.iconName.isEmpty ? "📝" : item.iconName)
                                        .mimiFont(20)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.categoryPath.components(separatedBy: "-").last ?? item.categoryPath)
                                        .mimiFont(14, weight: .semibold)
                                        .foregroundColor(MimiTheme.textPrimary)

                                    HStack(spacing: 6) {
                                        Text(formattedTime(item.date))
                                            .mimiFont(11)
                                            .foregroundColor(MimiTheme.textMuted)

                                        if !item.note.isEmpty {
                                            Text("| \(item.note)")
                                                .mimiFont(11)
                                                .foregroundColor(MimiTheme.textSecondary)
                                                .lineLimit(1)
                                        }

                                        Text(item.accountName)
                                            .mimiFont(10, weight: .medium)
                                            .foregroundColor(MimiTheme.textSecondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(MimiTheme.fillSubtle))
                                    }
                                }

                                Spacer()

                                Text(item.type == .expense ? "-\(MimiTheme.formatRM(item.amount))" : "+\(MimiTheme.formatRM(item.amount))")
                                    .mimiFont(15, weight: .bold, design: .rounded)
                                    .foregroundColor(item.type == .expense ? MimiTheme.expenseDeep : MimiTheme.incomeOrange)
                            }
                            .padding(14)
                        }
                        .mimiPressable()

                        if index < selectedDateTransactions.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(MimiTheme.cardBackground))
            }
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Floating Bottom Bar (Capybara + 任何事都能问我 + Add Button)

    private var floatingBottomBar: some View {
        HStack(spacing: 10) {
            Button {
                onOpenAsk()
            } label: {
                HStack(spacing: 8) {
                    MimiAskMascotView(size: 32)
                    Text("任何事都能问我")
                        .mimiFont(13, weight: .medium)
                        .foregroundColor(MimiTheme.textMuted)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minHeight: MimiHIG.minTouch)
                .background(Capsule().fill(MimiTheme.cardBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            }
            .mimiPressable()
            .accessibilityLabel("问账")
            .accessibilityHint("打开 AI 问账")

            Button {
                onOpenRecord()
            } label: {
                Image(systemName: "plus")
                    .mimiFont(16, weight: .bold)
                    .foregroundColor(MimiTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(MimiTheme.cardBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            }
            .mimiPressable()
            .accessibilityLabel("记一笔")
        }
    }
}
