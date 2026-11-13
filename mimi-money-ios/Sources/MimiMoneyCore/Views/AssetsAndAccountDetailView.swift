import SwiftUI

public struct AssetsAndAccountDetailView: View {
    @ObservedObject public var store: MimiStore
    public var onDismiss: () -> Void

    @State private var selectedAccountID: String?
    @State private var showBalanceEditSheet: Bool = false
    @State private var newBalanceInput: String = ""
    @State private var balanceEditMode: Int = 0 // 0: 设定期初起始资金, 1: 校准当前余额
    @State private var detailTabMode: String = "明细" // "明细" (audit logs) vs "账单" (bills)
    @State private var showAddAccountSheet: Bool = false
    @State private var newAccountName: String = ""
    @State private var newAccountBalance: String = ""
    @State private var billForDetail: TransactionItem? = nil

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
                            .mimiFont(15, weight: .semibold)
                            .foregroundColor(MimiTheme.textPrimary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showAddAccountSheet = true
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "plus")
                                .mimiFont(12, weight: .bold)
                            Text("添加账户")
                                .mimiFont(13, weight: .semibold)
                        }
                        .foregroundColor(MimiTheme.expenseBlue)
                    }
                }
            }
            .navigationDestination(item: $selectedAccountID) { accountID in
                if let account = store.accounts.first(where: { $0.id == accountID }) {
                    accountDetailSheet(for: account)
                } else {
                    Text("账户不存在")
                        .foregroundColor(MimiTheme.textMuted)
                }
            }
            // 账单详情挂在资产 NavigationStack 上，避免账户详情再嵌套 sheet
            .sheet(item: $billForDetail) { tx in
                BillDetailSheetView(store: store, transaction: tx) {
                    billForDetail = nil
                }
            }
            .sheet(isPresented: $showAddAccountSheet) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("新增资产账户")
                            .mimiFont(18, weight: .bold)
                            .foregroundColor(MimiTheme.textPrimary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("账户名称")
                                .mimiFont(13, weight: .medium)
                                .foregroundColor(MimiTheme.textSecondary)
                            TextField("例如: Maybank / GrabPay / 备用金", text: $newAccountName)
                                .mimiFont(14)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(MimiTheme.background))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("起始开局余额 (RM)")
                                .mimiFont(13, weight: .medium)
                                .foregroundColor(MimiTheme.textSecondary)
                            TextField("0.00", text: $newAccountBalance)
                                .mimiFont(14)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(MimiTheme.background))
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
                                .mimiFont(15, weight: .bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.expenseBlue))
                        }
                        .mimiPressable()

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
                .mimiFont(13, weight: .medium)
                .foregroundColor(MimiTheme.textSecondary)

            Text(MimiTheme.formatRM(store.netWorth))
                .mimiFont(28, weight: .bold, design: .rounded)
                .foregroundColor(store.netWorth < -0.0001 ? MimiTheme.dangerEmphasis : MimiTheme.textPrimary)

            HStack(spacing: 24) {
                Text("资产 \(MimiTheme.formatRM(store.totalAssets))")
                    .mimiFont(12)
                    .foregroundColor(store.totalAssets < -0.0001 ? MimiTheme.dangerEmphasis : MimiTheme.textSecondary)
                Text("负债 \(MimiTheme.formatRM(store.totalLiabilities))")
                    .mimiFont(12)
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
                .mimiFont(13, weight: .medium)
                .foregroundColor(MimiTheme.textSecondary)
            Spacer()
            Text(MimiTheme.formatRM(store.pendingReimbursementAmount))
                .mimiFont(15, weight: .bold, design: .rounded)
                .foregroundColor(MimiTheme.textPrimary)
            Image(systemName: "chevron.right")
                .mimiFont(11, weight: .semibold)
                .foregroundColor(MimiTheme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(MimiTheme.surfaceMuted))
    }

    // MARK: - Account List Card (现金, CIMB, TNGewallet, PBBank)

    private var accountGroupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("资金账户 (资产)")
                    .mimiFont(14, weight: .bold)
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
                Button {
                    showAddAccountSheet = true
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "plus")
                            .mimiFont(11, weight: .bold)
                        Text("添加账户")
                            .mimiFont(12, weight: .semibold)
                    }
                    .foregroundColor(MimiTheme.expenseBlue)
                }
                .mimiPressable()
            }

            ForEach(store.accounts) { account in
                Button {
                    newBalanceInput = String(format: "%.2f", account.balance)
                    detailTabMode = "明细"
                    showBalanceEditSheet = false
                    selectedAccountID = account.id
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
                                .mimiFont(15, weight: .semibold)
                                .foregroundColor(MimiTheme.textPrimary)
                            Text(account.subtitle)
                                .mimiFont(11)
                                .foregroundColor(MimiTheme.textMuted)
                        }

                        Spacer()

                        Text(MimiTheme.formatRM(account.balance))
                            .mimiFont(16, weight: .bold, design: .rounded)
                            .foregroundColor(account.balance < -0.0001 ? MimiTheme.dangerEmphasis : MimiTheme.textPrimary)

                        Image(systemName: "chevron.right")
                            .mimiFont(11)
                            .foregroundColor(MimiTheme.textMuted)
                    }
                    .padding(.vertical, 8)
                }
                .mimiPressable()

                if account.id != store.accounts.last?.id {
                    Divider()
                }
            }

        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(MimiTheme.cardBackground))
    }

    // MARK: - Account Detail (push，避免 sheet 套 sheet 点了卡住)

    private func accountDetailSheet(for initialAccount: AccountItem) -> some View {
        let liveAccount = store.accounts.first(where: { $0.id == initialAccount.id }) ?? initialAccount
        let auditLogs = store.auditLogs(for: liveAccount.name)
        let bills = store.transactions.filter {
            $0.accountName == liveAccount.name || $0.accountId == liveAccount.id
        }

        return ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    // Gold cream account header: icon · name · 自定义余额 · … / 余额 / 记账·转账
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            MimiStickerIconView(
                                iconName: liveAccount.iconName,
                                categoryName: liveAccount.name,
                                transactionType: .income,
                                size: 44
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(liveAccount.name)
                                    .mimiFont(17, weight: .bold)
                                    .foregroundColor(MimiTheme.textPrimary)
                                Text(liveAccount.subtitle.isEmpty ? "自定义余额" : liveAccount.subtitle)
                                    .mimiFont(12)
                                    .foregroundColor(MimiTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "ellipsis")
                                .mimiFont(14, weight: .semibold)
                                .foregroundColor(MimiTheme.iconInactive)
                        }

                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0.5))
                            path.addLine(to: CGPoint(x: 2000, y: 0.5))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundColor(MimiTheme.assetAccent)
                        .frame(height: 1)
                        .clipped()

                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("余额")
                                    .mimiFont(12)
                                    .foregroundColor(MimiTheme.textSecondary)
                                HStack(spacing: 6) {
                                    Text(MimiTheme.formatRM(liveAccount.balance))
                                        .mimiFont(28, weight: .bold, design: .rounded)
                                        .foregroundColor(liveAccount.balance < -0.0001 ? MimiTheme.dangerEmphasis : MimiTheme.textPrimary)
                                    Button {
                                        showBalanceEditSheet.toggle()
                                    } label: {
                                        Image(systemName: "pencil")
                                            .mimiFont(13, weight: .semibold)
                                            .foregroundColor(MimiTheme.iconInactive)
                                    }
                                    .mimiPressable()
                                }
                            }
                            Spacer()
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
                                        .mimiFont(14, weight: .bold)
                                        .foregroundColor(MimiTheme.textSecondary)

                                    TextField("输入金额", text: $newBalanceInput)
                                        .mimiFont(14)
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(MimiTheme.cardBackground))

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
                                    .mimiFont(13, weight: .bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(MimiTheme.expenseBlue))
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            accountActionPill(title: "记账", systemName: "plus") {
                                showBalanceEditSheet = false
                            }
                            accountActionPill(title: "转账", systemName: "arrow.left.arrow.right") {
                                showBalanceEditSheet = false
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(MimiTheme.assetCream)
                    )

                    HStack {
                        Text(detailTabMode == "明细" ? "账户明细" : "账户账单")
                            .mimiFont(15, weight: .bold)
                            .foregroundColor(MimiTheme.textPrimary)
                        Spacer()
                        HStack(spacing: 0) {
                            ForEach(
                                [("明细", "calendar"), ("账单", "doc.text")],
                                id: \.0
                            ) { tab, icon in
                                Button {
                                    detailTabMode = tab
                                } label: {
                                    Image(systemName: icon)
                                        .mimiFont(13, weight: .semibold)
                                        .foregroundColor(detailTabMode == tab ? MimiTheme.expenseBlue : MimiTheme.textMuted)
                                        .frame(width: 36, height: 28)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(detailTabMode == tab ? MimiTheme.tintBlueChip : Color.clear)
                                        )
                                }
                                .mimiPressable()
                                .accessibilityLabel(tab)
                            }
                        }
                        .padding(3)
                        .background(RoundedRectangle(cornerRadius: 10).fill(MimiTheme.fillSubtle))
                    }

                    if detailTabMode == "明细" {
                        HStack {
                            Text("2026年11月")
                                .mimiFont(13, weight: .semibold)
                                .foregroundColor(MimiTheme.textSecondary)
                            Image(systemName: "chevron.down")
                                .mimiFont(10, weight: .bold)
                                .foregroundColor(MimiTheme.textMuted)
                            Spacer()
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(auditLogs.enumerated()), id: \.element.id) { idx, log in
                                Button {
                                    if let tx = store.transaction(forAuditLog: log) {
                                        billForDetail = tx
                                    }
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(formattedBillTime(log.loggedAt))
                                            .mimiFont(12, weight: .medium, design: .rounded)
                                            .foregroundColor(MimiTheme.textMuted)
                                            .frame(width: 36, alignment: .leading)

                                        VStack(spacing: 0) {
                                            Text(log.action.rawValue)
                                                .mimiFont(10, weight: .bold)
                                                .foregroundColor(.white)
                                                .frame(width: 22, height: 22)
                                                .background(Circle().fill(badgeColor(for: log.action)))
                                            if idx < auditLogs.count - 1 {
                                                Rectangle()
                                                    .fill(MimiTheme.divider)
                                                    .frame(width: 1)
                                                    .frame(maxHeight: .infinity)
                                            }
                                        }
                                        .frame(width: 22)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(auditTypeLabel(log))
                                                .mimiFont(13, weight: .semibold)
                                                .foregroundColor(MimiTheme.textPrimary)
                                            if !log.note.isEmpty {
                                                Text(log.note)
                                                    .mimiFont(12)
                                                    .foregroundColor(MimiTheme.textSecondary)
                                                    .lineLimit(2)
                                            }
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar")
                                                    .mimiFont(10)
                                                Text("账单日期 \(formattedBillDate(log.billDate))")
                                                    .mimiFont(11)
                                            }
                                            .foregroundColor(MimiTheme.textMuted)
                                        }

                                        Spacer(minLength: 6)

                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text("余额: \(MimiTheme.formatRM(log.balanceAfter))")
                                                .mimiFont(11, design: .rounded)
                                                .foregroundColor(MimiTheme.textMuted)
                                            Text(
                                                log.deltaAmount >= 0
                                                    ? MimiTheme.formatRM(log.deltaAmount)
                                                    : "-\(MimiTheme.formatRM(abs(log.deltaAmount)))"
                                            )
                                            .mimiFont(15, weight: .bold, design: .rounded)
                                            .strikethrough(log.action == .deleted && log.deltaAmount < 0, color: MimiTheme.textMuted)
                                            .foregroundColor(
                                                log.action == .deleted && log.deltaAmount < 0
                                                    ? MimiTheme.textMuted
                                                    : (log.deltaAmount >= 0 ? MimiTheme.incomeOrange : MimiTheme.expenseBlue)
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .mimiPressable()
                                .disabled(store.transaction(forAuditLog: log) == nil)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 18).fill(MimiTheme.cardBackground))
                    } else {
                        accountBillsSection(bills: bills)
                    }
                }
                .padding(16)
            }
        .background(MimiTheme.background.ignoresSafeArea())
        .navigationTitle("账户详情")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    selectedAccountID = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .mimiFont(15, weight: .semibold)
                        .foregroundColor(MimiTheme.textPrimary)
                }
            }
        }
    }

    private func accountActionPill(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .mimiFont(12, weight: .semibold)
                Text(title)
                    .mimiFont(14, weight: .semibold)
            }
            .foregroundColor(MimiTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Capsule().fill(MimiTheme.cardBackground))
        }
        .mimiPressable()
    }

    private func auditTypeLabel(_ log: AccountAuditLog) -> String {
        let kind: String
        switch log.transactionType {
        case .income: kind = "收入"
        case .expense: kind = "支出"
        case .transfer: kind = "转账"
        }
        return "\(kind) | \(log.categoryTitle)"
    }

    private func formattedBillDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: date)
    }

    @ViewBuilder
    private func accountBillsSection(bills: [TransactionItem]) -> some View {
        let cal = Calendar(identifier: .gregorian)
        let outflow = bills.filter { $0.type == .expense || $0.type == .transfer }.reduce(0.0) { $0 + $1.amount }
        let inflow = bills.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
        let grouped: [(key: DateComponents, items: [TransactionItem])] = {
            let dict = Dictionary(grouping: bills) { tx in
                cal.dateComponents([.year, .month, .day], from: tx.date)
            }
            return dict.keys.sorted {
                let a = cal.date(from: $0) ?? .distantPast
                let b = cal.date(from: $1) ?? .distantPast
                return a > b
            }.map { ($0, dict[$0] ?? []) }
        }()

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("2026年11月")
                    .mimiFont(14, weight: .bold)
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
                Text("流出 \(MimiTheme.formatRM(outflow))")
                    .mimiFont(12, weight: .semibold, design: .rounded)
                    .foregroundColor(MimiTheme.expenseBlue)
                Text("流入 \(MimiTheme.formatRM(inflow))")
                    .mimiFont(12, weight: .semibold, design: .rounded)
                    .foregroundColor(MimiTheme.incomeOrange)
            }

            if grouped.isEmpty {
                Text("暂无账单")
                    .mimiFont(13)
                    .foregroundColor(MimiTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(RoundedRectangle(cornerRadius: 16).fill(MimiTheme.cardBackground))
            } else {
                ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                    let dayDate = cal.date(from: group.key) ?? Date()
                    let weekday = cal.component(.weekday, from: dayDate)
                    let weekdayMap = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
                    let dayLabel = String(
                        format: "%d月%d日 (%@)",
                        group.key.month ?? 0,
                        group.key.day ?? 0,
                        (weekday >= 1 && weekday <= 7) ? weekdayMap[weekday] : ""
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text(dayLabel)
                            .mimiFont(12, weight: .semibold)
                            .foregroundColor(MimiTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .padding(.bottom, 6)

                        ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, tx in
                            Button {
                                billForDetail = tx
                            } label: {
                                HStack(spacing: 12) {
                                    MimiStickerIconView(
                                        iconName: tx.iconName,
                                        categoryName: tx.categoryPath,
                                        transactionType: tx.type,
                                        size: 34
                                    )
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(tx.categoryPath.components(separatedBy: "-").last ?? tx.categoryPath)
                                            .mimiFont(14, weight: .semibold)
                                            .foregroundColor(MimiTheme.textPrimary)
                                        HStack(spacing: 4) {
                                            Text(formattedBillTime(tx.date))
                                                .mimiFont(11)
                                                .foregroundColor(MimiTheme.textMuted)
                                            if !tx.note.isEmpty {
                                                Text("| \(tx.note)")
                                                    .mimiFont(11)
                                                    .foregroundColor(MimiTheme.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Text(tx.accountName)
                                            .mimiFont(10, weight: .medium)
                                            .foregroundColor(MimiTheme.textSecondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(MimiTheme.fillSubtle))
                                    }
                                    Spacer()
                                    Text(tx.type == .expense || tx.type == .transfer
                                         ? "-\(MimiTheme.formatRM(tx.amount))"
                                         : MimiTheme.formatRM(tx.amount))
                                        .mimiFont(15, weight: .bold, design: .rounded)
                                        .foregroundColor(tx.type == .expense || tx.type == .transfer
                                                         ? MimiTheme.expenseBlue
                                                         : MimiTheme.incomeOrange)
                                    Image(systemName: "chevron.right")
                                        .mimiFont(11, weight: .semibold)
                                        .foregroundColor(MimiTheme.controlDisabled)
                                }
                                .padding(14)
                                .contentShape(Rectangle())
                            }
                            .mimiPressable()
                            if idx < group.items.count - 1 {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 16).fill(MimiTheme.cardBackground))
                }
            }
        }
    }

    private func formattedBillTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
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
