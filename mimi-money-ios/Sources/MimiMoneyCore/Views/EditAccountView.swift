import SwiftUI

/// Gold「编辑账户」：名称 / 图标 / 备注 + 计入总资产 / 特别关注 / 默认收支账户。
public struct EditAccountView: View {
    @ObservedObject public var store: MimiStore
    public var accountId: String
    public var onDismiss: () -> Void
    public var onDeleted: () -> Void

    @State private var nameText: String = ""
    @State private var noteText: String = ""
    @State private var iconName: String = "💳"
    @State private var includeInAssets: Bool = true
    @State private var isSpecialFocus: Bool = false
    @State private var isDefaultAccount: Bool = false
    @State private var showIconPicker: Bool = false
    @State private var showDeleteConfirm: Bool = false

    public init(
        store: MimiStore,
        accountId: String,
        onDismiss: @escaping () -> Void,
        onDeleted: @escaping () -> Void = {}
    ) {
        self.store = store
        self.accountId = accountId
        self.onDismiss = onDismiss
        self.onDeleted = onDeleted
    }

    private var account: AccountItem? {
        store.accounts.first(where: { $0.id == accountId })
    }

    private var canSave: Bool {
        !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var stickerIcons: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for section in MimiStickerIconView.stickerGalleryItems {
            for icon in section.icons where seen.insert(icon).inserted {
                result.append(icon)
            }
        }
        if result.isEmpty {
            result = DefaultCatalog.stickerIconLibrary()
        }
        return result
    }

    public var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    VStack(spacing: 0) {
                        editRow(title: "账户名称") {
                            HStack(spacing: 8) {
                                TextField("账户名称", text: $nameText)
                                    .mimiFont(15, weight: .medium)
                                    .foregroundColor(MimiTheme.textPrimary)
                                    .multilineTextAlignment(.trailing)
                                Image(systemName: "pencil")
                                    .mimiFont(12, weight: .medium)
                                    .foregroundColor(MimiTheme.iconInactive)
                            }
                        }
                        Divider().padding(.leading, 16)
                        Button {
                            showIconPicker = true
                        } label: {
                            editRow(title: "账户图标") {
                                HStack(spacing: 8) {
                                    MimiStickerIconView(
                                        iconName: iconName,
                                        categoryName: nameText.isEmpty ? "账户" : nameText,
                                        transactionType: .income,
                                        size: 32
                                    )
                                    Image(systemName: "chevron.right")
                                        .mimiFont(12, weight: .semibold)
                                        .foregroundColor(MimiTheme.iconInactive)
                                }
                            }
                        }
                        .mimiPressable()
                        .accessibilityLabel(MimiL10n.string("账户图标"))
                        .accessibilityHint(MimiL10n.string("点按选择图标"))
                        Divider().padding(.leading, 16)
                        editRow(title: "备注") {
                            HStack(spacing: 8) {
                                TextField("备注", text: $noteText)
                                    .mimiFont(15, weight: .medium)
                                    .foregroundColor(MimiTheme.textPrimary)
                                    .multilineTextAlignment(.trailing)
                                Image(systemName: "pencil")
                                    .mimiFont(12, weight: .medium)
                                    .foregroundColor(MimiTheme.iconInactive)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(MimiTheme.cardBackground))

                    VStack(spacing: 0) {
                        toggleRow(
                            title: "计入总资产",
                            subtitle: "关闭后不计入净资产与资产合计",
                            isOn: $includeInAssets
                        )
                        Divider().padding(.leading, 16)
                        toggleRow(
                            title: "设为特别关注账户",
                            subtitle: "特别关注的账户可在资金账户列表顶部查看",
                            isOn: $isSpecialFocus
                        )
                        Divider().padding(.leading, 16)
                        toggleRow(
                            title: "设为默认收支账户",
                            subtitle: "记账时若未指定账户，将默认使用此账户",
                            isOn: $isDefaultAccount
                        )
                    }
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(MimiTheme.cardBackground))
                }
                .padding(16)
                .padding(.bottom, 88)
            }
            .background(MimiTheme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button(action: save) {
                    Text("保存", bundle: .mimiModule)
                        .mimiFont(16, weight: .bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: MimiHIG.minTouch)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MimiTheme.expenseBlue))
                }
                .mimiPressable()
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(MimiTheme.background.ignoresSafeArea(edges: .bottom))
                .accessibilityLabel(MimiL10n.string("保存"))
            }
            .navigationTitle(MimiL10n.string("编辑账户"))
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
                    .accessibilityLabel(MimiL10n.string("返回"))
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .mimiFont(15, weight: .semibold)
                            .foregroundColor(MimiTheme.dangerRed)
                    }
                    .accessibilityLabel(MimiL10n.string("删除账户"))
                    .disabled(store.accounts.count <= 1)
                }
            }
            .onAppear(perform: loadFromAccount)
            .alert(MimiL10n.string("删除账户？"), isPresented: $showDeleteConfirm) {
                Button(MimiL10n.string("删除"), role: .destructive) {
                    store.deleteAccount(accountId: accountId)
                    onDeleted()
                    onDismiss()
                }
                Button(MimiL10n.string("取消"), role: .cancel) {}
            } message: {
                Text("删除后不可恢复。相关账单仍会保留，但不再关联此账户余额。", bundle: .mimiModule)
            }
            .sheet(isPresented: $showIconPicker) {
                iconPickerSheet
                    .mimiInteractiveSheet(detents: [.medium, .large])
            }
        }
    }

    private func loadFromAccount() {
        guard let account else { return }
        nameText = account.name
        noteText = account.subtitle
        iconName = account.iconName
        includeInAssets = account.includeInAssets
        isSpecialFocus = account.isSpecialFocus
        isDefaultAccount = account.isDefaultAccount
    }

    private func save() {
        guard var account = account else { return }
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        account.name = trimmed
        account.subtitle = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        account.iconName = iconName
        account.includeInAssets = includeInAssets
        account.isSpecialFocus = isSpecialFocus
        account.isDefaultAccount = isDefaultAccount
        store.updateAccount(account)
        onDismiss()
    }

    private func editRow<Content: View>(title: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .mimiFont(15, weight: .medium)
                .foregroundColor(MimiTheme.textPrimary)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: MimiHIG.minTouch)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .mimiFont(15, weight: .medium)
                    .foregroundColor(MimiTheme.textPrimary)
                Text(subtitle)
                    .mimiFont(12)
                    .foregroundColor(MimiTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(MimiTheme.expenseBlue)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: MimiHIG.minTouch)
    }

    private var iconPickerSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(stickerIcons, id: \.self) { icon in
                        Button {
                            iconName = icon
                            showIconPicker = false
                        } label: {
                            MimiStickerIconView(
                                iconName: icon,
                                categoryName: nameText.isEmpty ? "账户" : nameText,
                                transactionType: .income,
                                size: 44
                            )
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(icon == iconName ? MimiTheme.tintBlueChip : MimiTheme.fillSubtle)
                            )
                        }
                        .mimiPressable()
                        .accessibilityLabel("图标 \(icon)")
                    }
                }
                .padding(16)
            }
            .background(MimiTheme.background.ignoresSafeArea())
            .navigationTitle(MimiL10n.string("选择图标"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(MimiL10n.string("关闭")) { showIconPicker = false }
                }
            }
        }
    }
}
