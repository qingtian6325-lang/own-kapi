import SwiftUI

public enum DrawerDestination: String, Identifiable, Sendable {
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
    @ObservedObject public var store: KapiStore
    public var onClose: () -> Void
    public var onSelectDestination: (DrawerDestination) -> Void

    public init(
        store: KapiStore,
        onClose: @escaping () -> Void,
        onSelectDestination: @escaping (DrawerDestination) -> Void
    ) {
        self.store = store
        self.onClose = onClose
        self.onSelectDestination = onSelectDestination
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
                                .foregroundColor(KapiTheme.textPrimary)
                            Text("已开启智能记账守护")
                                .font(.system(size: 11))
                                .foregroundColor(KapiTheme.textSecondary)
                        }

                        Spacer()

                        Button {
                            onSelectDestination(.settings)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(KapiTheme.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white))
                        }
                    }
                    .padding(.top, 12)

                    // November 2026 Check-in Heatmap & Stats Card (IMG_2249)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("November 2026")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(KapiTheme.textPrimary)
                            Spacer()
                            // Mini 5x6 dot check-in matrix
                            HStack(spacing: 3) {
                                ForEach(0..<10, id: \.self) { idx in
                                    Circle()
                                        .fill(idx >= 7 ? KapiTheme.expenseBlue : Color(hex: 0xDCE4F7))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }

                        HStack(spacing: 0) {
                            statColumn(value: "\(store.recordedDaysCount)", label: "记录天数")
                            Divider().frame(height: 28)
                            statColumn(value: "\(store.totalRecordsCount)", label: "总记录")
                            Divider().frame(height: 28)
                            statColumn(value: "\(store.streakDaysCount)", label: "连续天数")
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                    )

                    // 更多功能 (7-item grid matching IMG_2249)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("更多功能")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(KapiTheme.textSecondary)

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
                            .foregroundColor(KapiTheme.textSecondary)

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
            .background(KapiTheme.background.ignoresSafeArea())
        }
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(KapiTheme.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(KapiTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
                    .foregroundColor(KapiTheme.textPrimary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
