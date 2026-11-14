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
    @State private var renameTarget: CategoryRenameTarget?
    @State private var renameText: String = ""
    @State private var deletePrimaryConfirmId: String?
    @State private var isReorderMode: Bool = false

    private struct CategoryRenameTarget: Identifiable {
        enum Kind { case primary, subcategory(groupId: String) }
        let id: String
        let kind: Kind
        let currentName: String
    }

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
                                    .mimiFont(16, weight: .bold)
                                    .foregroundColor(MimiTheme.textPrimary)
                                Spacer()
                                Menu {
                                    Button {
                                        newCategoryName = ""
                                        useFirstCharAsIcon = true
                                        selectedStickerEmoji = "🍮"
                                        showAddPrimarySheet = true
                                    } label: {
                                        Label("添加一级分类", systemImage: "plus")
                                    }
                                    Button {
                                        isReorderMode.toggle()
                                    } label: {
                                        Label(
                                            isReorderMode ? "完成排序" : "排序分类",
                                            systemImage: isReorderMode ? "checkmark" : "arrow.up.arrow.down"
                                        )
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(MimiTheme.textMuted)
                                        .frame(width: MimiHIG.minTouch, height: MimiHIG.minTouch)
                                        .contentShape(Rectangle())
                                }
                                .accessibilityLabel("分类更多操作")
                            }
                            Text("支出 \(store.expenseCategories.count) 类 | 收入 \(store.incomeCategories.count) 类")
                                .mimiFont(12)
                                .foregroundColor(MimiTheme.textSecondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(MimiTheme.cardBackground))

                        // Pill tabs: 支出 | 收入
                        HStack(spacing: 0) {
                            Button { selectedTab = .expense } label: {
                                Text("支出")
                                    .mimiFont(13, weight: selectedTab == .expense ? .bold : .medium)
                                    .foregroundColor(selectedTab == .expense ? MimiTheme.expenseBlue : MimiTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(selectedTab == .expense ? Color.white : Color.clear))
                            }
                            .mimiPressable()
                            Button { selectedTab = .income } label: {
                                Text("收入")
                                    .mimiFont(13, weight: selectedTab == .income ? .bold : .medium)
                                    .foregroundColor(selectedTab == .income ? MimiTheme.expenseBlue : MimiTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(selectedTab == .income ? Color.white : Color.clear))
                            }
                            .mimiPressable()
                        }
                        .padding(4)
                        .background(Capsule().fill(MimiTheme.fillSubtle))

                        // 4-column category grid (gold 标准分类 modal)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                            ForEach(Array(activeGroups.enumerated()), id: \.element.id) { index, group in
                                VStack(spacing: 6) {
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
                                                        .mimiFont(9, weight: .bold)
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(Capsule().fill(MimiTheme.textMuted))
                                                        .offset(x: 4, y: 4)
                                                }
                                            }
                                            Text(group.name)
                                                .mimiFont(11, weight: .medium)
                                                .foregroundColor(MimiTheme.textPrimary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .mimiPressable()

                                    if isReorderMode {
                                        HStack(spacing: 10) {
                                            Button {
                                                store.movePrimaryCategory(
                                                    type: selectedTab,
                                                    from: index,
                                                    to: max(0, index - 1)
                                                )
                                            } label: {
                                                Image(systemName: "chevron.up")
                                                    .mimiFont(12, weight: .bold)
                                                    .frame(width: 28, height: 28)
                                            }
                                            .disabled(index == 0)
                                            .mimiPressable()
                                            .accessibilityLabel("上移 \(group.name)")

                                            Button {
                                                store.movePrimaryCategory(
                                                    type: selectedTab,
                                                    from: index,
                                                    to: min(activeGroups.count - 1, index + 1)
                                                )
                                            } label: {
                                                Image(systemName: "chevron.down")
                                                    .mimiFont(12, weight: .bold)
                                                    .frame(width: 28, height: 28)
                                            }
                                            .disabled(index >= activeGroups.count - 1)
                                            .mimiPressable()
                                            .accessibilityLabel("下移 \(group.name)")
                                        }
                                        .foregroundColor(MimiTheme.expenseBlue)
                                    }
                                }
                                .contextMenu {
                                    Button("重命名") {
                                        renameText = group.name
                                        renameTarget = CategoryRenameTarget(
                                            id: group.id,
                                            kind: .primary,
                                            currentName: group.name
                                        )
                                    }
                                    Button("删除", role: .destructive) {
                                        deletePrimaryConfirmId = group.id
                                    }
                                    .disabled(activeGroups.count <= 1)
                                }
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
                                            .fill(MimiTheme.pillGray)
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "plus")
                                            .mimiFont(18, weight: .semibold)
                                            .foregroundColor(MimiTheme.textSecondary)
                                    }
                                    Text("添加")
                                        .mimiFont(11, weight: .medium)
                                        .foregroundColor(MimiTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .mimiPressable()
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(MimiTheme.cardBackground))

                        Text(isReorderMode ? "使用上下箭头调整分类顺序" : "点击分类管理二级；⋯ 可添加或排序；长按分类可重命名/删除")
                            .mimiFont(12)
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
                            .mimiFont(15, weight: .semibold)
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
                            .mimiFont(16, weight: .semibold)
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
            .alert(
                "重命名分类",
                isPresented: Binding(
                    get: { renameTarget != nil },
                    set: { if !$0 { renameTarget = nil } }
                )
            ) {
                TextField("名称", text: $renameText)
                Button("保存") { commitRename() }
                Button("取消", role: .cancel) { renameTarget = nil }
            } message: {
                Text("修改后会更新显示名称。")
            }
            .alert(
                "删除一级分类？",
                isPresented: Binding(
                    get: { deletePrimaryConfirmId != nil },
                    set: { if !$0 { deletePrimaryConfirmId = nil } }
                )
            ) {
                Button("删除", role: .destructive) {
                    if let id = deletePrimaryConfirmId {
                        store.deletePrimaryCategory(id: id, type: selectedTab)
                    }
                    deletePrimaryConfirmId = nil
                }
                Button("取消", role: .cancel) { deletePrimaryConfirmId = nil }
            } message: {
                Text("已有账单不会被删除，只是不再挂在此分类下展示。")
            }
        }
    }

    private func commitRename() {
        guard let target = renameTarget else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            renameTarget = nil
            return
        }
        switch target.kind {
        case .primary:
            store.renamePrimaryCategory(id: target.id, type: selectedTab, newName: trimmed)
        case .subcategory(let groupId):
            store.renameSubcategory(groupId: groupId, subId: target.id, type: selectedTab, newName: trimmed)
        }
        renameTarget = nil
    }

    // MARK: - Subcategory Management Bottom Sheet (gold: icon + name + … / gray rows)

    private func subcategoryManagerSheet(for group: CategoryGroup) -> some View {
        let liveGroup = (selectedTab == .expense
            ? store.expenseCategories
            : store.incomeCategories).first(where: { $0.id == group.id }) ?? group

        return VStack(spacing: 14) {
            Capsule()
                .fill(MimiTheme.strokeSubtle)
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            HStack(spacing: 12) {
                MimiStickerIconView(
                    iconName: liveGroup.displayBadgeToken,
                    categoryName: liveGroup.name,
                    transactionType: selectedTab,
                    useFirstCharIcon: liveGroup.useFirstCharIcon,
                    size: 42
                )
                Text(liveGroup.name)
                    .mimiFont(18, weight: .bold)
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
                Menu {
                    Button("重命名一级分类") {
                        renameText = liveGroup.name
                        renameTarget = CategoryRenameTarget(
                            id: liveGroup.id,
                            kind: .primary,
                            currentName: liveGroup.name
                        )
                    }
                    Button("添加二级分类") {
                        isAddingSubcategory = true
                        newSubcategoryName = ""
                    }
                    Button("删除一级分类", role: .destructive) {
                        deletePrimaryConfirmId = liveGroup.id
                        selectedGroupForSubSheet = nil
                    }
                    .disabled(activeGroups.count <= 1)
                } label: {
                    Image(systemName: "ellipsis")
                        .mimiFont(14, weight: .semibold)
                        .foregroundColor(MimiTheme.iconInactive)
                        .frame(width: MimiHIG.minTouch, height: MimiHIG.minTouch)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("一级分类操作")
            }
            .padding(.horizontal, 20)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(liveGroup.subcategories.enumerated()), id: \.element.id) { index, sub in
                        HStack(spacing: 10) {
                            MimiStickerIconView(
                                iconName: sub.iconName,
                                categoryName: sub.name,
                                transactionType: selectedTab,
                                useFirstCharIcon: sub.useFirstCharIcon,
                                size: 34
                            )
                            Button {
                                renameText = sub.name
                                renameTarget = CategoryRenameTarget(
                                    id: sub.id,
                                    kind: .subcategory(groupId: liveGroup.id),
                                    currentName: sub.name
                                )
                            } label: {
                                HStack(spacing: 6) {
                                    Text(sub.name)
                                        .mimiFont(15, weight: .medium)
                                        .foregroundColor(MimiTheme.textPrimary)
                                    Image(systemName: "pencil")
                                        .mimiFont(11, weight: .medium)
                                        .foregroundColor(MimiTheme.iconInactive)
                                }
                            }
                            .mimiPressable()
                            .accessibilityLabel("重命名 \(sub.name)")

                            Spacer(minLength: 8)

                            Button {
                                store.moveSubcategory(
                                    groupId: liveGroup.id,
                                    type: selectedTab,
                                    from: index,
                                    to: max(0, index - 1)
                                )
                            } label: {
                                Image(systemName: "chevron.up")
                                    .mimiFont(12, weight: .semibold)
                                    .foregroundColor(MimiTheme.iconInactive)
                                    .frame(width: 28, height: 28)
                            }
                            .disabled(index == 0)
                            .mimiPressable()
                            .accessibilityLabel("上移")

                            Button {
                                store.moveSubcategory(
                                    groupId: liveGroup.id,
                                    type: selectedTab,
                                    from: index,
                                    to: min(liveGroup.subcategories.count - 1, index + 1)
                                )
                            } label: {
                                Image(systemName: "chevron.down")
                                    .mimiFont(12, weight: .semibold)
                                    .foregroundColor(MimiTheme.iconInactive)
                                    .frame(width: 28, height: 28)
                            }
                            .disabled(index >= liveGroup.subcategories.count - 1)
                            .mimiPressable()
                            .accessibilityLabel("下移")

                            Menu {
                                Button("重命名") {
                                    renameText = sub.name
                                    renameTarget = CategoryRenameTarget(
                                        id: sub.id,
                                        kind: .subcategory(groupId: liveGroup.id),
                                        currentName: sub.name
                                    )
                                }
                                Button("删除", role: .destructive) {
                                    store.deleteSubcategory(
                                        groupId: liveGroup.id,
                                        subId: sub.id,
                                        type: selectedTab
                                    )
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .mimiFont(13, weight: .semibold)
                                    .foregroundColor(MimiTheme.iconInactive)
                                    .frame(width: MimiHIG.minTouch, height: MimiHIG.minTouch)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("二级分类操作")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MimiTheme.background))
                    }

                    if isAddingSubcategory {
                        HStack(spacing: 10) {
                            TextField("输入二级分类名称", text: $newSubcategoryName)
                                .mimiFont(14)
                            Button("添加") {
                                commitNewSubcategory(to: liveGroup)
                            }
                            .mimiFont(14, weight: .semibold)
                            .foregroundColor(MimiTheme.expenseBlue)
                            .disabled(newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MimiTheme.background))
                    }

                    Button {
                        if isAddingSubcategory {
                            commitNewSubcategory(to: liveGroup)
                        } else {
                            isAddingSubcategory = true
                            newSubcategoryName = ""
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .mimiFont(14, weight: .semibold)
                            Text("添加二级分类")
                                .mimiFont(14, weight: .medium)
                            Spacer(minLength: 0)
                        }
                        .foregroundColor(MimiTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MimiTheme.background))
                    }
                    .mimiPressable()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(MimiTheme.cardBackground.ignoresSafeArea())
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
                .fill(MimiTheme.strokeSubtle)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 12)

            Text(selectedTab == .income ? "添加1级收入分类" : "添加1级支出分类")
                .mimiFont(16, weight: .bold)
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
                            .strokeBorder(MimiTheme.divider, lineWidth: 1.5)
                            .background(Circle().fill(MimiTheme.cardBackground))
                            .frame(width: 52, height: 52)
                    }
                }

                HStack(spacing: 8) {
                    TextField("请输入分类名称 (必填)", text: $newCategoryName)
                        .mimiFont(16, weight: .medium)
                        .foregroundColor(MimiTheme.textPrimary)
                    Image(systemName: "pencil")
                        .mimiFont(13, weight: .medium)
                        .foregroundColor(MimiTheme.iconInactive)
                }
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(MimiTheme.divider)
                        .frame(height: 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            Toggle(isOn: $useFirstCharAsIcon) {
                Text("首字作为图标")
                    .mimiFont(14, weight: .medium)
                    .foregroundColor(MimiTheme.textPrimary)
            }
            .tint(MimiTheme.expenseBlue)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MimiTheme.background))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            HStack {
                Text("分类图标")
                    .mimiFont(12, weight: .medium)
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
                                .strokeBorder(MimiTheme.divider, lineWidth: 1)
                                .background(Circle().fill(MimiTheme.cardBackground))
                                .frame(width: 52, height: 52)
                            Image(systemName: "plus")
                                .mimiFont(18, weight: .semibold)
                                .foregroundColor(MimiTheme.textSecondary)
                        }
                    }
                    .mimiPressable()

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
                        .mimiPressable()
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
                    .mimiFont(16, weight: .semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? MimiTheme.ringProgress
                                    : MimiTheme.expenseBlue
                            )
                    )
            }
            .mimiPressable()
            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(MimiTheme.cardBackground.ignoresSafeArea())
        .onAppear {
            newCategoryName = ""
            useFirstCharAsIcon = true
            selectedStickerEmoji = "🍮"
        }
    }
}
