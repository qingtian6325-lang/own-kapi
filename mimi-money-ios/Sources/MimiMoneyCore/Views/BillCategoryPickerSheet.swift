import SwiftUI

/// Bottom sheet: 标准分类 — primary 4-col grid + expandable secondary 5-col card + 确认.
public struct BillCategoryPickerSheet: View {
    @ObservedObject public var store: MimiStore
    public var initialType: TransactionType
    public var initialCategoryPath: String
    public var onConfirm: (_ type: TransactionType, _ categoryPath: String, _ iconName: String) -> Void
    public var onDismiss: () -> Void
    public var onEditCategories: () -> Void

    @State private var selection: BillCategorySelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        store: MimiStore,
        initialType: TransactionType,
        initialCategoryPath: String,
        onConfirm: @escaping (_ type: TransactionType, _ categoryPath: String, _ iconName: String) -> Void,
        onDismiss: @escaping () -> Void,
        onEditCategories: @escaping () -> Void
    ) {
        self.store = store
        self.initialType = initialType == .transfer ? .expense : initialType
        self.initialCategoryPath = initialCategoryPath
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        self.onEditCategories = onEditCategories
        let seedType = initialType == .transfer ? .expense : initialType
        _selection = State(
            initialValue: BillCategorySelection.from(
                type: seedType,
                categoryPath: initialCategoryPath,
                expenseCategories: store.expenseCategories,
                incomeCategories: store.incomeCategories
            )
        )
    }

    private var activeGroups: [CategoryGroup] {
        selection.type == .income ? store.incomeCategories : store.expenseCategories
    }

    private var selectedGroup: CategoryGroup? {
        guard let id = selection.primaryId else { return nil }
        return activeGroups.first(where: { $0.id == id })
    }

    public var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(MimiTheme.strokeSubtle)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 8)

            header
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            typeCapsule
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            TabView(selection: Binding(
                get: { selection.type },
                set: { newType in
                    guard newType == .expense || newType == .income else { return }
                    guard selection.type != newType else { return }
                    withAnimation(MimiMotion.quick(reduceMotion: reduceMotion)) {
                        selection = BillCategorySelection(type: newType)
                    }
                }
            )) {
                categoryPage(for: .expense).tag(TransactionType.expense)
                categoryPage(for: .income).tag(TransactionType.income)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .frame(maxHeight: .infinity)

            confirmButton
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .background(MimiTheme.cardBackground)
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        #endif
    }

    private var header: some View {
        HStack {
            Text("标准分类", bundle: .mimiModule)
                .mimiFont(17, weight: .bold)
                .foregroundColor(MimiTheme.textPrimary)
            Spacer()
            Button(action: onEditCategories) {
                Text("分类编辑", bundle: .mimiModule)
                    .mimiFont(14, weight: .medium)
                    .foregroundColor(MimiTheme.expenseBlue)
                    .padding(.horizontal, 4)
                    .frame(minHeight: MimiHIG.minTouch)
                    .contentShape(Rectangle())
            }
            .mimiPressable()
            .accessibilityLabel(MimiL10n.string("分类编辑"))
        }
    }

    private var typeCapsule: some View {
        HStack(spacing: 0) {
            ForEach([TransactionType.expense, TransactionType.income], id: \.self) { type in
                let selected = selection.type == type
                Button {
                    guard selection.type != type else { return }
                    withAnimation(MimiMotion.quick(reduceMotion: reduceMotion)) {
                        selection = BillCategorySelection(type: type)
                    }
                } label: {
                    Text(type.rawValue)
                        .mimiFont(14, weight: selected ? .bold : .medium)
                        .foregroundColor(selected ? MimiTheme.textPrimary : MimiTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected ? MimiTheme.cardBackground : Color.clear)
                                .shadow(
                                    color: selected ? Color.black.opacity(0.08) : .clear,
                                    radius: 3,
                                    x: 0,
                                    y: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(type.rawValue))
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(MimiTheme.progressTrack))
    }

    private func categoryPage(for type: TransactionType) -> some View {
        let groups = type == .income ? store.incomeCategories : store.expenseCategories
        let selectedOnThisPage = selection.type == type
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                primaryGrid(groups: groups, type: type, selectedOnThisPage: selectedOnThisPage)
                if selectedOnThisPage,
                   let group = selectedGroup,
                   !group.subcategories.isEmpty {
                    secondaryCard(for: group)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private func primaryGrid(
        groups: [CategoryGroup],
        type: TransactionType,
        selectedOnThisPage: Bool
    ) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
            spacing: 16
        ) {
            ForEach(groups) { group in
                let isSelected = selectedOnThisPage && selection.primaryId == group.id
                Button {
                    withAnimation(MimiMotion.quick(reduceMotion: reduceMotion)) {
                        if selection.type != type {
                            selection = BillCategorySelection(type: type, primaryId: group.id)
                        } else if selection.primaryId != group.id {
                            selection.primaryId = group.id
                            selection.secondaryId = nil
                        }
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottomTrailing) {
                            MimiStickerIconView(
                                iconName: group.displayBadgeToken,
                                categoryName: group.name,
                                transactionType: type,
                                useFirstCharIcon: group.useFirstCharIcon,
                                size: 56,
                                isSelected: isSelected
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        isSelected ? MimiTheme.expenseBlue : Color.clear,
                                        lineWidth: 2.5
                                    )
                            )

                            if !group.subcategories.isEmpty {
                                Image(systemName: "chevron.down")
                                    .mimiFont(8, weight: .bold)
                                    .foregroundColor(isSelected ? .white : MimiTheme.textSecondary)
                                    .frame(width: 16, height: 16)
                                    .background(
                                        Circle()
                                            .fill(isSelected ? MimiTheme.expenseBlue : MimiTheme.fillSubtle)
                                    )
                                    .offset(x: 2, y: 2)
                                    .accessibilityHidden(true)
                            }
                        }

                        Text(group.name)
                            .mimiFont(12, weight: isSelected ? .bold : .medium)
                            .foregroundColor(isSelected ? MimiTheme.expenseBlue : MimiTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(group.name))
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }

    private func secondaryCard(for group: CategoryGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.name)
                .mimiFont(13, weight: .semibold)
                .foregroundColor(MimiTheme.textSecondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                spacing: 12
            ) {
                ForEach(group.subcategories) { sub in
                    let isSelected = selection.secondaryId == sub.id
                    Button {
                        selection.secondaryId = sub.id
                    } label: {
                        VStack(spacing: 6) {
                            MimiStickerIconView(
                                iconName: sub.iconName,
                                categoryName: sub.name,
                                transactionType: selection.type,
                                useFirstCharIcon: sub.useFirstCharIcon,
                                size: 44,
                                isSelected: isSelected
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        isSelected ? MimiTheme.expenseBlue : Color.clear,
                                        lineWidth: 2
                                    )
                            )

                            Text(sub.name)
                                .mimiFont(11, weight: isSelected ? .bold : .regular)
                                .foregroundColor(isSelected ? MimiTheme.expenseBlue : MimiTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(sub.name))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MimiTheme.fillSubtle)
        )
    }

    private var confirmButton: some View {
        Button {
            guard let resolved = selection.resolvedPath(in: activeGroups) else { return }
            onConfirm(selection.type, resolved.path, resolved.iconName)
        } label: {
            Text("确认", bundle: .mimiModule)
                .mimiFont(17, weight: .bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            selection.primaryId == nil
                                ? MimiTheme.controlDisabled
                                : MimiTheme.expenseBlue
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(selection.primaryId == nil)
        .accessibilityLabel(MimiL10n.string("确认"))
    }
}
