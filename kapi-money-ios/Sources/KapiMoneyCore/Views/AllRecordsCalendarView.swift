import SwiftUI

public struct AllRecordsCalendarView: View {
    @ObservedObject public var store: KapiStore
    public var onDismiss: () -> Void
    public var onSelectTransaction: (TransactionItem) -> Void

    @State private var selectedYear: Int = 2026
    @State private var selectedMonth: Int = 11
    @State private var selectedDay: Int = 8
    @State private var filterMode: String = "收支" // "收支" or "支出"
    @State private var searchQuery: String = ""
    @State private var showSearchField: Bool = false

    public init(
        store: KapiStore,
        onDismiss: @escaping () -> Void,
        onSelectTransaction: @escaping (TransactionItem) -> Void
    ) {
        self.store = store
        self.onDismiss = onDismiss
        self.onSelectTransaction = onSelectTransaction
    }

    private var dayCells: [CalendarDaySummary] {
        DynamicBudgetEngine.buildMonthDayCells(
            year: selectedYear,
            month: selectedMonth,
            transactions: store.transactions
        )
    }

    private var selectedDateTransactions: [TransactionItem] {
        let cal = Calendar(identifier: .gregorian)
        return store.transactions.filter { tx in
            let comps = cal.dateComponents([.year, .month, .day], from: tx.date)
            guard comps.year == selectedYear && comps.month == selectedMonth && comps.day == selectedDay else {
                return false
            }
            if filterMode == "支出" && tx.type != .expense {
                return false
            }
            if !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                return tx.categoryPath.lowercased().contains(q)
                    || tx.note.lowercased().contains(q)
                    || tx.accountName.lowercased().contains(q)
            }
            return true
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    monthSelectorAndLegendBar

                    if showSearchField {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(KapiTheme.textMuted)
                            TextField("搜索分类、备注、账户...", text: $searchQuery)
                                .font(.system(size: 14))
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    }

                    calendarGridCard

                    selectedDayTransactionsSection
                }
                .padding(16)
            }
            .background(KapiTheme.background.ignoresSafeArea())
            .navigationTitle("全部记录")
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
                    HStack(spacing: 10) {
                        Button {
                            withAnimation {
                                showSearchField.toggle()
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(KapiTheme.textPrimary)
                        }

                        Menu {
                            Button("收支") { filterMode = "收支" }
                            Button("支出") { filterMode = "支出" }
                        } label: {
                            HStack(spacing: 3) {
                                Text(filterMode)
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(KapiTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Month Selector + 回今天 + Heatmap Legend (IMG_2250–2252)

    private var monthSelectorAndLegendBar: some View {
        HStack {
            HStack(spacing: 8) {
                Button {
                    if selectedMonth > 1 { selectedMonth -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(KapiTheme.textSecondary)
                }

                Text(String(format: "%d年%02d月", selectedYear, selectedMonth))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(KapiTheme.textPrimary)

                Button {
                    if selectedMonth < 12 { selectedMonth += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(KapiTheme.textSecondary)
                }

                Button {
                    selectedYear = 2026
                    selectedMonth = 11
                    selectedDay = 8
                } label: {
                    Text("回今天")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(KapiTheme.expenseBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: 0xE8F0FE)))
                }
            }

            Spacer()

            // Orange-to-Blue Heatmap Legend (收入多 🟧⬜🟦 支出多)
            HStack(spacing: 4) {
                Text("收入多")
                    .font(.system(size: 10))
                    .foregroundColor(KapiTheme.textMuted)
                RoundedRectangle(cornerRadius: 2).fill(KapiTheme.incomeOrange.opacity(0.75)).frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xEEF0F6)).frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: 2).fill(KapiTheme.expenseBlue.opacity(0.85)).frame(width: 8, height: 8)
                Text("支出多")
                    .font(.system(size: 10))
                    .foregroundColor(KapiTheme.textMuted)
            }
        }
    }

    // MARK: - 7-Column Calendar Heatmap Grid

    private var calendarGridCard: some View {
        let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
        return VStack(spacing: 10) {
            HStack {
                ForEach(weekdays, id: \.self) { w in
                    Text(w)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(KapiTheme.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(dayCells) { cell in
                    let isSelected = cell.day == selectedDay
                    Button {
                        selectedDay = cell.day
                    } label: {
                        VStack(spacing: 2) {
                            HStack(spacing: 2) {
                                Text("\(cell.day)")
                                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                                    .foregroundColor(isSelected ? .white : KapiTheme.textPrimary)
                                if cell.isHighestExpenseDay {
                                    Text("👑")
                                        .font(.system(size: 9))
                                }
                            }

                            if cell.expense > 0 {
                                Text(String(format: "-%.0f", cell.expense))
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundColor(isSelected ? .white.opacity(0.9) : KapiTheme.expenseBlue)
                                    .lineLimit(1)
                            } else {
                                Text(" ")
                                    .font(.system(size: 9))
                            }

                            if cell.income > 0 && filterMode == "收支" {
                                Text(String(format: "+%.0f", cell.income))
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundColor(isSelected ? .white.opacity(0.9) : KapiTheme.incomeOrange)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(cellBackground(for: cell, isSelected: isSelected))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
    }

    private func cellBackground(for cell: CalendarDaySummary, isSelected: Bool) -> Color {
        if isSelected {
            return KapiTheme.expenseBlue
        }
        if cell.expense > 150 {
            return KapiTheme.expenseBlue.opacity(0.22)
        } else if cell.expense > 0 {
            return KapiTheme.expenseBlue.opacity(0.10)
        } else if cell.income > 0 {
            return KapiTheme.incomeOrange.opacity(0.16)
        }
        return Color(hex: 0xF7F8FC)
    }

    // MARK: - Selected Day Transactions & 收支分析 Pill

    private var selectedDayTransactionsSection: some View {
        let dayExp = selectedDateTransactions.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
        let dayInc = selectedDateTransactions.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(selectedMonth)月\(selectedDay)日 明细")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)

                Spacer()

                Text("收支分析 · 支 \(KapiTheme.formatRM(dayExp)) / 收 \(KapiTheme.formatRM(dayInc))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(KapiTheme.textSecondary)
            }

            if selectedDateTransactions.isEmpty {
                Text("当日暂无账单记录")
                    .font(.system(size: 13))
                    .foregroundColor(KapiTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            } else {
                VStack(spacing: 0) {
                    ForEach(selectedDateTransactions) { item in
                        Button {
                            onSelectTransaction(item)
                        } label: {
                            HStack(spacing: 12) {
                                KapiStickerIconView(
                                    iconName: item.iconName,
                                    categoryName: item.categoryPath,
                                    transactionType: item.type,
                                    size: 36
                                )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.categoryPath)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(KapiTheme.textPrimary)
                                    Text("\(item.accountName) · \(item.note)")
                                        .font(.system(size: 11))
                                        .foregroundColor(KapiTheme.textMuted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(item.type == .expense ? "-\(KapiTheme.formatRM(item.amount))" : "+\(KapiTheme.formatRM(item.amount))")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(item.type == .expense ? KapiTheme.expenseBlue : KapiTheme.incomeOrange)
                            }
                            .padding(14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            }
        }
    }
}
