import SwiftUI

public struct CategoryManagementView: View {
    @ObservedObject public var store: MimiStore
    public var onDismiss: () -> Void

    @State private var selectedTab: TransactionType = .expense
    @State private var selectedGroupForSubSheet: CategoryGroup?
    @State private var showAddPrimarySheet: Bool = false

    // Add 1st-level Category State (IMG_2293)
    @State private var newCategoryName: String = ""
    @State private var useFirstCharAsIcon: Bool = false
    @State private var selectedStickerEmoji: String = "🍮"
    @State private var newSubcategoryName: String = ""

    public init(store: MimiStore, onDismiss: @escaping () -> Void) {
        self.store = store
        self.onDismiss = onDismiss
    }

    private var activeGroups: [CategoryGroup] {
        selectedTab == .income ? store.incomeCategories : store.expenseCategories
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        // Gold: 标准分类 summary card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("标准分类")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(MimiTheme.textPrimary)
                                Spacer()
                                Image(systemName: "ellipsis")
                                    .foregroundColor(MimiTheme.textMuted)
                            }
                            Text("支出 \(store.expenseCategories.count) 类 | 收入 \(store.incomeCategories.count) 类")
                                .font(.system(size: 12))
                                .foregroundColor(MimiTheme.textSecondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))

                        // Pill tabs: 支出 | 收入
                        HStack(spacing: 0) {
                            Button { selectedTab = .expense } label: {
                                Text("支出")
                                    .font(.system(size: 13, weight: selectedTab == .expense ? .bold : .medium))
                                    .foregroundColor(selectedTab == .expense ? MimiTheme.expenseBlue : MimiTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(selectedTab == .expense ? Color.white : Color.clear))
                            }
                            .buttonStyle(.plain)
                            Button { selectedTab = .income } label: {
                                Text("收入")
                                    .font(.system(size: 13, weight: selectedTab == .income ? .bold : .medium))
                                    .foregroundColor(selectedTab == .income ? MimiTheme.expenseBlue : MimiTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(selectedTab == .income ? Color.white : Color.clear))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(4)
                        .background(Capsule().fill(Color(hex: 0xEEF0F6)))

                        // 4-column category grid (gold 标准分类 modal)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                            ForEach(activeGroups) { group in
                                Button {
                                    selectedGroupForSubSheet = group
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack(alignment: .bottomTrailing) {
                                            MimiStickerIconView(
                                                iconName: group.displayBadgeToken,
                                                categoryName: group.name,
                                                transactionType: selectedTab,
                                                useFirstCharIcon: group.useFirstCharIcon,
                                                size: 48
                                            )
                                            if !group.subcategories.isEmpty {
                                                Text("\(group.subcategories.count)")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Capsule().fill(Color(hex: 0x9CA3AF)))
                                                    .offset(x: 4, y: 4)
                                            }
                                        }
                                        Text(group.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(MimiTheme.textPrimary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                newCategoryName = ""
                                useFirstCharAsIcon = false
                                showAddPrimarySheet = true
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: 0xF3F4F6))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "plus")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(MimiTheme.textSecondary)
                                    }
                                    Text("添加")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(MimiTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))

                        Text("点击编辑，长按排序")
                            .font(.system(size: 12))
                            .foregroundColor(MimiTheme.textMuted)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }

            }
            .background(MimiTheme.background.ignoresSafeArea())
            .navigationTitle("分类方案管理")
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
                    Text("默认方案 ⌄")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(MimiTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(hex: 0xF2F4F8)))
                }
            }
            .sheet(item: $selectedGroupForSubSheet) { group in
                subcategoryManagerSheet(for: group)
            }
            .sheet(isPresented: $showAddPrimarySheet) {
                addPrimaryCategorySheet
            }
        }
    }

    // MARK: - Subcategory Management Bottom Sheet (IMG_2268–2292)

    private func subcategoryManagerSheet(for group: CategoryGroup) -> some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    MimiStickerIconView(
                        iconName: group.displayBadgeToken,
                        categoryName: group.name,
                        transactionType: selectedTab,
                        useFirstCharIcon: group.useFirstCharIcon,
                        size: 42
                    )
                    Text(group.name)
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                    Image(systemName: "ellipsis")
                        .foregroundColor(MimiTheme.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(group.subcategories) { sub in
                            HStack(spacing: 12) {
                                MimiStickerIconView(
                                    iconName: sub.iconName,
                                    categoryName: sub.name,
                                    transactionType: selectedTab,
                                    useFirstCharIcon: sub.useFirstCharIcon,
                                    size: 36
                                )
                                Text(sub.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(MimiTheme.textPrimary)
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundColor(MimiTheme.textMuted)
                                Spacer()
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(MimiTheme.textMuted)
                                Image(systemName: "ellipsis")
                                    .foregroundColor(MimiTheme.textMuted)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xF5F6FA)))
                        }

                        HStack {
                            Image(systemName: "plus")
                            Text("添加二级分类")
                            Spacer()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(MimiTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xF5F6FA)))
                    }
                    .padding(16)
                }

                HStack(spacing: 10) {
                    TextField("输入新二级分类名称...", text: $newSubcategoryName)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))

                    Button("+ 添加子类") {
                        let trimmed = newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        store.addSubcategory(
                            toGroupId: group.id,
                            type: selectedTab,
                            name: trimmed,
                            iconName: group.iconName,
                            useFirstCharIcon: false
                        )
                        newSubcategoryName = ""
                        selectedGroupForSubSheet = nil
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(MimiTheme.expenseBlue))
                }
                .padding(16)
            }
            .background(MimiTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { selectedGroupForSubSheet = nil }
                }
            }
        }
    }

    // MARK: - 添加1级支出分类 Sheet with 首字作为图标（包含emoji） + Sticker Gallery (IMG_2293)

    private var addPrimaryCategorySheet: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    MimiStickerIconView(
                        iconName: useFirstCharAsIcon ? String(newCategoryName.prefix(1)) : selectedStickerEmoji,
                        categoryName: newCategoryName.isEmpty ? "新" : newCategoryName,
                        transactionType: selectedTab,
                        useFirstCharIcon: useFirstCharAsIcon,
                        size: 46
                    )

                    TextField("输入分类名称（最多6个字）", text: $newCategoryName)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Toggle: 首字作为图标（包含emoji） (IMG_2293)
                Toggle(isOn: $useFirstCharAsIcon) {
                    Text("首字作为图标（包含emoji）")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(MimiTheme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                .padding(.horizontal, 16)

                // Categorized 100+ Sticker Gallery
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(MimiStickerIconView.stickerGalleryItems, id: \.category) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.category)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(MimiTheme.textSecondary)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                                    ForEach(section.icons, id: \.self) { emoji in
                                        Button {
                                            selectedStickerEmoji = emoji
                                        } label: {
                                            MimiStickerIconView(
                                                iconName: emoji,
                                                categoryName: newCategoryName,
                                                transactionType: selectedTab,
                                                useFirstCharIcon: false,
                                                size: 40,
                                                isSelected: selectedStickerEmoji == emoji && !useFirstCharAsIcon
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .background(MimiTheme.background.ignoresSafeArea())
            .navigationTitle(selectedTab == .income ? "添加1级收入分类" : "添加1级支出分类")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAddPrimarySheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        store.addPrimaryCategory(
                            type: selectedTab,
                            name: String(trimmed.prefix(6)),
                            iconName: selectedStickerEmoji,
                            useFirstCharIcon: useFirstCharAsIcon
                        )
                        showAddPrimarySheet = false
                    }
                    .font(.system(size: 14, weight: .bold))
                }
            }
        }
    }
}
