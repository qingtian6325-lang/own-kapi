import SwiftUI

public struct CategoryManagementView: View {
    @ObservedObject public var store: MimiStore
    public var onDismiss: () -> Void

    @State private var selectedTab: TransactionType = .expense
    @State private var selectedGroupForSubSheet: CategoryGroup?
    @State private var showAddPrimarySheet: Bool = false

    // Add 1st-level Category State (IMG_2293)
    @State private var newCategoryName: String = ""
    @State private var useFirstCharAsIcon: Bool = true
    @State private var selectedStickerEmoji: String = "🍮"
    @State private var newSubcategoryName: String = ""
    @State private var isAddingSubcategory: Bool = false

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
                                useFirstCharAsIcon = true
                                selectedStickerEmoji = "🍮"
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
                    Button {
                        newCategoryName = ""
                        useFirstCharAsIcon = true
                        selectedStickerEmoji = "🍮"
                        showAddPrimarySheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(MimiTheme.textPrimary)
                    }
                }
            }
            .sheet(item: $selectedGroupForSubSheet) { group in
                subcategoryManagerSheet(for: group)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddPrimarySheet) {
                addPrimaryCategorySheet
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Subcategory Management Bottom Sheet (gold: icon + name + … / gray rows)

    private func subcategoryManagerSheet(for group: CategoryGroup) -> some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Color(hex: 0xD8DCE6))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            HStack(spacing: 12) {
                MimiStickerIconView(
                    iconName: group.displayBadgeToken,
                    categoryName: group.name,
                    transactionType: selectedTab,
                    useFirstCharIcon: group.useFirstCharIcon,
                    size: 42
                )
                Text(group.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: 0xC0C4CE))
            }
            .padding(.horizontal, 20)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(group.subcategories) { sub in
                        HStack(spacing: 10) {
                            MimiStickerIconView(
                                iconName: sub.iconName,
                                categoryName: sub.name,
                                transactionType: selectedTab,
                                useFirstCharIcon: sub.useFirstCharIcon,
                                size: 34
                            )
                            Text(sub.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(MimiTheme.textPrimary)
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: 0xC0C4CE))
                            Spacer(minLength: 8)
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: 0xC0C4CE))
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: 0xC0C4CE))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xF5F6FA)))
                    }

                    if isAddingSubcategory {
                        HStack(spacing: 10) {
                            TextField("输入二级分类名称", text: $newSubcategoryName)
                                .font(.system(size: 14))
                            Button("添加") {
                                commitNewSubcategory(to: group)
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MimiTheme.expenseBlue)
                            .disabled(newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xF5F6FA)))
                    }

                    Button {
                        if isAddingSubcategory {
                            commitNewSubcategory(to: group)
                        } else {
                            isAddingSubcategory = true
                            newSubcategoryName = ""
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("添加二级分类")
                                .font(.system(size: 14, weight: .medium))
                            Spacer(minLength: 0)
                        }
                        .foregroundColor(MimiTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xF5F6FA)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .onDisappear {
            isAddingSubcategory = false
            newSubcategoryName = ""
        }
    }

    private func commitNewSubcategory(to group: CategoryGroup) {
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
        isAddingSubcategory = false
    }

    // MARK: - 添加1级分类 Sheet (gold: 请输入分类名称 + 首字开关 + 5 列图标 + 确认)

    private var flatStickerIcons: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for section in MimiStickerIconView.stickerGalleryItems {
            for icon in section.icons {
                if seen.insert(icon).inserted {
                    result.append(icon)
                }
            }
        }
        return result
    }

    private var addPrimaryCategorySheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(hex: 0xD8DCE6))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 12)

            Text(selectedTab == .income ? "添加1级收入分类" : "添加1级支出分类")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(MimiTheme.textPrimary)
                .padding(.bottom, 16)

            HStack(spacing: 14) {
                Group {
                    if useFirstCharAsIcon, !newCategoryName.isEmpty {
                        MimiStickerIconView(
                            iconName: String(newCategoryName.prefix(1)),
                            categoryName: newCategoryName,
                            transactionType: selectedTab,
                            useFirstCharIcon: true,
                            size: 52
                        )
                    } else if !useFirstCharAsIcon {
                        MimiStickerIconView(
                            iconName: selectedStickerEmoji,
                            categoryName: newCategoryName.isEmpty ? "新" : newCategoryName,
                            transactionType: selectedTab,
                            useFirstCharIcon: false,
                            size: 52
                        )
                    } else {
                        Circle()
                            .strokeBorder(Color(hex: 0xE5E7EB), lineWidth: 1.5)
                            .background(Circle().fill(Color(hex: 0xFAFBFC)))
                            .frame(width: 52, height: 52)
                    }
                }

                HStack(spacing: 8) {
                    TextField("请输入分类名称 (必填)", text: $newCategoryName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(MimiTheme.textPrimary)
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: 0xC0C4CE))
                }
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(hex: 0xECEEF3))
                        .frame(height: 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            Toggle(isOn: $useFirstCharAsIcon) {
                Text("首字作为图标")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MimiTheme.textPrimary)
            }
            .tint(MimiTheme.expenseBlue)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xF5F6FA)))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            HStack {
                Text("分类图标")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(MimiTheme.textMuted)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    Button {
                        useFirstCharAsIcon = false
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(Color(hex: 0xE5E7EB), lineWidth: 1)
                                .background(Circle().fill(Color.white))
                                .frame(width: 52, height: 52)
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(MimiTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(flatStickerIcons.prefix(59), id: \.self) { emoji in
                        Button {
                            selectedStickerEmoji = emoji
                            useFirstCharAsIcon = false
                        } label: {
                            MimiStickerIconView(
                                iconName: emoji,
                                categoryName: newCategoryName,
                                transactionType: selectedTab,
                                useFirstCharIcon: false,
                                size: 48,
                                isSelected: selectedStickerEmoji == emoji && !useFirstCharAsIcon
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            Button {
                let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                store.addPrimaryCategory(
                    type: selectedTab,
                    name: String(trimmed.prefix(6)),
                    iconName: selectedStickerEmoji,
                    useFirstCharIcon: useFirstCharAsIcon
                )
                showAddPrimarySheet = false
            } label: {
                Text("确认")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color(hex: 0xB8C7F5)
                                    : MimiTheme.expenseBlue
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            newCategoryName = ""
            useFirstCharAsIcon = true
            selectedStickerEmoji = "🍮"
        }
    }
}
