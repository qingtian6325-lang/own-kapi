import SwiftUI

public enum DrawerDestination: String, Identifiable, Sendable {
    case calendar = "全部记录"
    case stats = "图表统计"
    case assets = "资产管理"
    case ledgers = "账本管理"
    case budgets = "预算管理"
    case widgets = "小组件"
    case categories = "分类管理"
    case tags = "标签管理"
    case importExport = "导入导出"
    case autoBookkeeping = "自动记账"
    case scheduledBookkeeping = "定时记账"
    case settings = "设置"

    public var id: String { rawValue }
}

public struct SideDrawerMenuView: View {
    @ObservedObject public var store: MimiStore
    public var onClose: () -> Void
    public var onSelectDestination: (DrawerDestination) -> Void

    public init(
        store: MimiStore,
        onClose: @escaping () -> Void,
        onSelectDestination: @escaping (DrawerDestination) -> Void
    ) {
        self.store = store
        self.onClose = onClose
        self.onSelectDestination = onSelectDestination
    }

    private var monthDayCells: [CalendarDaySummary] {
        DynamicBudgetEngine.buildMonthDayCells(year: 2026, month: 11, transactions: store.transactions)
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // User Profile Header (IMG_2249)
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: 0xFFE8CC))
                                .frame(width: 48, height: 48)
                            Text("🐱")
                                .font(.system(size: 26))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.userNickname)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(MimiTheme.textPrimary)
                            Text("已开启智能记账守护")
                                .font(.system(size: 11))
                                .foregroundColor(MimiTheme.textSecondary)
                        }

                        Spacer()

                        Button {
                            onSelectDestination(.settings)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(MimiTheme.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white))
                        }
                    }
                    .padding(.top, 12)

                    // November 2026 Heatmap & Stats Card (IMG_2249 + User Requested Calendar Entry)
                    Button {
                        onSelectDestination(.calendar)
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("November 2026")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(MimiTheme.textPrimary)

                                Spacer()

                                HStack(spacing: 2) {
                                    Text("全部记录")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(MimiTheme.expenseBlue)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(MimiTheme.expenseBlue)
                                }
                            }

                            // Mini Month Calendar Heatmap (1-30 days, deep/light blue & orange)
                            VStack(spacing: 4) {
                                HStack(spacing: 0) {
                                    ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { w in
                                        Text(w)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(MimiTheme.textMuted)
                                            .frame(maxWidth: .infinity)
                                    }
                                }

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
                                    // 2026年11月1日是周日，周一开始排前面空6格
                                    ForEach(0..<6, id: \.self) { _ in
                                        Color.clear
                                            .frame(height: 18)
                                    }
                                    ForEach(monthDayCells, id: \.id) { cell in
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .fill(heatmapMiniColor(for: cell))
                                                .frame(height: 18)

                                            Text("\(cell.day)")
                                                .font(.system(size: 9, weight: cell.isToday ? .bold : .regular, design: .rounded))
                                                .foregroundColor(cell.isToday ? MimiTheme.expenseBlue : (cell.expense > 0 || cell.income > 0 ? MimiTheme.textPrimary : MimiTheme.textMuted))
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)

                            // Heatmap Legend Indicator
                            HStack(spacing: 4) {
                                Text("收入多")
                                    .font(.system(size: 9))
                                    .foregroundColor(MimiTheme.textMuted)
                                RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: 0xFFD8B5)).frame(width: 8, height: 6)
                                RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: 0xFFEBD9)).frame(width: 8, height: 6)
                                RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: 0xF0F2F6)).frame(width: 8, height: 6)
                                RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: 0xDDE9FD)).frame(width: 8, height: 6)
                                RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: 0x90B8F8)).frame(width: 8, height: 6)
                                Text("支出多")
                                    .font(.system(size: 9))
                                    .foregroundColor(MimiTheme.textMuted)

                                Spacer()
                            }

                            Divider().opacity(0.6)

                            HStack(spacing: 0) {
                                statColumn(value: "\(store.recordedDaysCount)", label: "记录天数")
                                Divider().frame(height: 24)
                                statColumn(value: "\(store.totalRecordsCount)", label: "总记录")
                                Divider().frame(height: 24)
                                statColumn(value: "\(store.streakDaysCount)", label: "连续天数")
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)

                    // 更多功能 (7-item grid matching IMG_2249)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("更多功能")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(MimiTheme.textSecondary)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 16
                        ) {
                            drawerGridButton(icon: "📊", title: "图表统计", dest: .stats)
                            drawerGridButton(icon: "🏦", title: "资产管理", dest: .assets)
                            drawerGridButton(icon: "📒", title: "账本管理", dest: .ledgers)
                            drawerGridButton(icon: "🎯", title: "预算管理", dest: .budgets)
                            drawerGridButton(icon: "🧩", title: "小组件", dest: .widgets)
                            drawerGridButton(icon: "🗂️", title: "分类管理", dest: .categories)
                            drawerGridButton(icon: "🏷️", title: "标签管理", dest: .tags)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                    )

                    // 快捷记账 (3-item grid matching IMG_2249)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快捷记账")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(MimiTheme.textSecondary)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 16
                        ) {
                            drawerGridButton(icon: "📥", title: "导入导出", dest: .importExport)
                            drawerGridButton(icon: "⚡", title: "自动记账", dest: .autoBookkeeping)
                            drawerGridButton(icon: "⏰", title: "定时记账", dest: .scheduledBookkeeping)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                    )
                }
                .padding(18)
            }
            .frame(width: 315)
            .background(MimiTheme.background.ignoresSafeArea())
        }
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(MimiTheme.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(MimiTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func heatmapMiniColor(for cell: CalendarDaySummary) -> Color {
        if cell.income > 0 && cell.expense == 0 {
            if cell.income > 500 { return Color(hex: 0xFFD8B5) }
            return Color(hex: 0xFFEBD9)
        }
        if cell.expense > 0 {
            if cell.expense > 200 { return Color(hex: 0x90B8F8) }
            if cell.expense > 30 { return Color(hex: 0xC3D7FD) }
            return Color(hex: 0xDDE9FD)
        }
        return Color(hex: 0xF5F7FA)
    }

    private func drawerGridButton(icon: String, title: String, dest: DrawerDestination) -> some View {
        Button {
            onSelectDestination(dest)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: 0xF5F6FA))
                        .frame(width: 48, height: 48)
                    Text(icon)
                        .font(.system(size: 22))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(MimiTheme.textPrimary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
