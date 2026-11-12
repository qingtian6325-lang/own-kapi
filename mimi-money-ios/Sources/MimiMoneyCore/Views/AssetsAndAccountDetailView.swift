import SwiftUI

public struct AssetsAndAccountDetailView: View {
    @ObservedObject public var store: MimiStore
    public var onDismiss: () -> Void

    @State private var selectedAccount: AccountItem?
    @State private var showBalanceEditSheet: Bool = false
    @State private var newBalanceInput: String = ""
    @State private var balanceEditMode: Int = 0 // 0: 设定期初起始资金, 1: 校准当前余额
    @State private var detailTabMode: String = "明细" // "明细" (audit logs) vs "账单" (bills)
    @State private var showAddAccountSheet: Bool = false
    @State private var newAccountName: String = ""
    @State private var newAccountBalance: String = ""

    public init(store: MimiStore, onDismiss: @escaping () -> Void) {
        self.store = store
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    netWorthTopBanner
                    reimbursementAndLendingRow
                    accountGroupCard
                }
                .padding(16)
            }
            .background(MimiTheme.background.ignoresSafeArea())
            .navigationTitle("资产")
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
                        showAddAccountSheet = true
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("添加账户")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(MimiTheme.expenseBlue)
                    }
                }
            }
            .sheet(item: $selectedAccount) { account in
                accountDetailSheet(for: account)
            }
            .sheet(isPresented: $showAddAccountSheet) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("新增资产账户")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(MimiTheme.textPrimary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("账户名称")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(MimiTheme.textSecondary)
                            TextField("例如: Maybank / GrabPay / 备用金", text: $newAccountName)
                                .font(.system(size: 14))
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("起始开局余额 (RM)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(MimiTheme.textSecondary)
                            TextField("0.00", text: $newAccountBalance)
                                .font(.system(size: 14))
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))
                        }

                        Button {
                            let trimmed = newAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            let balanceVal = Double(newAccountBalance) ?? 0.0
                            let item = AccountItem(
                                id: "acc_\(UUID().uuidString.prefix(6))",
                                name: trimmed,
                                subtitle: "自定义账户",
                                iconName: "💳",
                                balance: balanceVal
                            )
                            store.addAccount(item)
                            showAddAccountSheet = false
                        } label: {
                            Text("保存并创建账户")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.expenseBlue))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(20)
                    .navigationTitle("添加账户")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") { showAddAccountSheet = false }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Net Worth Overview Banner (IMG_2258)

    private var netWorthTopBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("净资产")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(MimiTheme.textSecondary)

            Text(MimiTheme.formatRM(store.netWorth))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(store.netWorth < -0.0001 ? Color(hex: 0xE53935) : MimiTheme.textPrimary)

            HStack(spacing: 24) {
                Text("资产 \(MimiTheme.formatRM(store.totalAssets))")
                    .font(.system(size: 12))
                    .foregroundColor(store.totalAssets < -0.0001 ? Color(hex: 0xE53935) : MimiTheme.textSecondary)
                Text("负债 \(MimiTheme.formatRM(store.totalLiabilities))")
                    .font(.system(size: 12))
                    .foregroundColor(MimiTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(MimiTheme.assetCream)
        )
    }

    // MARK: - Reimbursement row (gold: single grey bar 待报销)

    private var reimbursementAndLendingRow: some View {
        HStack {
            Text("待报销")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(MimiTheme.textSecondary)
            Spacer()
            Text(MimiTheme.formatRM(store.pendingReimbursementAmount))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(MimiTheme.textPrimary)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(MimiTheme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xF0F1F5)))
    }

    // MARK: - Account List Card (现金, CIMB, TNGewallet, PBBank)

    private var accountGroupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("资金账户 (资产)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
                Button {
                    showAddAccountSheet = true
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("添加账户")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(MimiTheme.expenseBlue)
                }
                .buttonStyle(.plain)
            }

            ForEach(store.accounts) { account in
                Button {
                    newBalanceInput = String(format: "%.2f", account.balance)
                    selectedAccount = account
                } label: {
                    HStack(spacing: 12) {
                        MimiStickerIconView(
                            iconName: account.iconName,
                            categoryName: account.name,
                            transactionType: .income,
                            size: 40
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(MimiTheme.textPrimary)
                            Text(account.subtitle)
                                .font(.system(size: 11))
                                .foregroundColor(MimiTheme.textMuted)
                        }

                        Spacer()

                        Text(MimiTheme.formatRM(account.balance))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(account.balance < -0.0001 ? Color(hex: 0xE53935) : MimiTheme.textPrimary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundColor(MimiTheme.textMuted)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                if account.id != store.accounts.last?.id {
                    Divider()
                }
            }

            Divider()

            Button {
                newAccountName = ""
                newAccountBalance = "0.00"
                showAddAccountSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(MimiTheme.expenseBlue)
                    Text("添加自定义资产账户 (如 Maybank, GrabPay 等)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MimiTheme.expenseBlue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xEAF1FF)))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - Account Detail Sheet (IMG_2261 & IMG_2262: 明细 [记/改/删] vs 账单)

    private func accountDetailSheet(for initialAccount: AccountItem) -> some View {
        let liveAccount = store.accounts.first(where: { $0.id == initialAccount.id }) ?? initialAccount
        let auditLogs = store.auditLogs(for: liveAccount.name)
        let bills = store.transactions.filter { $0.accountName == liveAccount.name }

        return NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    // Top Blue Account Balance Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(liveAccount.name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(MimiTheme.textPrimary)
                            Spacer()
                            Button {
                                showBalanceEditSheet.toggle()
                            } label: {
                                Text("修改账户余额")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(MimiTheme.expenseBlue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.white))
                            }
                            .buttonStyle(.plain)
                        }

                        Text(MimiTheme.formatRM(liveAccount.balance))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(liveAccount.balance < -0.0001 ? Color(hex: 0xE53935) : MimiTheme.expenseBlue)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("记账前起始资金")
                                    .font(.system(size: 11))
                                    .foregroundColor(MimiTheme.textMuted)
                                Text(MimiTheme.formatRM(liveAccount.initialBalance))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(MimiTheme.textPrimary)
                            }

                            let delta = store.accountTransactionDelta(accountId: liveAccount.id)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("期间流水净变动")
                                    .font(.system(size: 11))
                                    .foregroundColor(MimiTheme.textMuted)
                                Text(MimiTheme.formatRM(delta))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(delta < -0.0001 ? Color(hex: 0xE53935) : MimiTheme.balanceGreen)
                            }
                        }

                        if showBalanceEditSheet {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("设置类型", selection: $balanceEditMode) {
                                    Text("设定期初资金(记账前)").tag(0)
                                    Text("校准当前余额(手机银行)").tag(1)
                                }
                                .pickerStyle(.segmented)

                                HStack(spacing: 8) {
                                    Text("RM")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(MimiTheme.textSecondary)

                                    TextField("输入金额", text: $newBalanceInput)
                                        .font(.system(size: 14))
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))

                                    Button("确定") {
                                        if let val = Double(newBalanceInput) {
                                            if balanceEditMode == 0 {
                                                store.setAccountInitialBalance(accountId: liveAccount.id, initialBalance: val)
                                            } else {
                                                store.updateAccountBalance(accountId: liveAccount.id, newBalance: val)
                                            }
                                        }
                                        showBalanceEditSheet = false
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(MimiTheme.expenseBlue))
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0xEAF1FF)))

                    // Toggle Header: 明细 (Audit Log) vs 账单 (Clean Bills)
                    HStack {
                        Text(detailTabMode == "明细" ? "账户操作审计明细" : "入账账单记录")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MimiTheme.textPrimary)

                        Spacer()

                        HStack(spacing: 4) {
                            ForEach(["明细", "账单"], id: \.self) { tab in
                                Button {
                                    detailTabMode = tab
                                } label: {
                                    Text(tab)
                                        .font(.system(size: 12, weight: detailTabMode == tab ? .bold : .medium))
                                        .foregroundColor(detailTabMode == tab ? .white : MimiTheme.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule().fill(detailTabMode == tab ? MimiTheme.expenseBlue : Color.white)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if detailTabMode == "明细" {
                        VStack(spacing: 0) {
                            ForEach(auditLogs) { log in
                                HStack(spacing: 10) {
                                    // 记 / 改 / 删 Badge (IMG_2261)
                                    Text(log.action.rawValue)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle().fill(badgeColor(for: log.action))
                                        )

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(log.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(MimiTheme.textPrimary)
                                        Text(log.subtitle)
                                            .font(.system(size: 11))
                                            .foregroundColor(MimiTheme.textMuted)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(
                                            log.deltaAmount >= 0
                                                ? "+\(MimiTheme.formatRM(log.deltaAmount))"
                                                : "-\(MimiTheme.formatRM(abs(log.deltaAmount)))"
                                        )
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .strikethrough(log.action == .deleted, color: MimiTheme.textMuted)
                                        .foregroundColor(
                                            log.action == .deleted
                                                ? MimiTheme.textMuted
                                                : (log.deltaAmount >= 0 ? MimiTheme.incomeOrange : MimiTheme.expenseBlue)
                                        )

                                        Text("余额: \(MimiTheme.formatRM(log.balanceAfter))")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundColor(MimiTheme.textMuted)
                                    }
                                }
                                .padding(14)
                                Divider()
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                    } else {
                        VStack(spacing: 0) {
                            ForEach(bills) { tx in
                                HStack(spacing: 12) {
                                    MimiStickerIconView(
                                        iconName: tx.iconName,
                                        categoryName: tx.categoryPath,
                                        transactionType: tx.type,
                                        size: 34
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tx.categoryPath)
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(tx.note)
                                            .font(.system(size: 11))
                                            .foregroundColor(MimiTheme.textMuted)
                                    }
                                    Spacer()
                                    Text(tx.type == .expense ? "-\(MimiTheme.formatRM(tx.amount))" : "+\(MimiTheme.formatRM(tx.amount))")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(tx.type == .expense ? MimiTheme.expenseBlue : MimiTheme.incomeOrange)
                                }
                                .padding(14)
                                Divider()
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                    }
                }
                .padding(16)
            }
            .background(MimiTheme.background.ignoresSafeArea())
            .navigationTitle("账户详情")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { selectedAccount = nil }
                }
            }
        }
    }

    private func badgeColor(for action: AuditActionType) -> Color {
        switch action {
        case .created:
            return MimiTheme.expenseBlue
        case .updated:
            return MimiTheme.incomeOrange
        case .deleted:
            return MimiTheme.dangerRed
        }
    }
}
