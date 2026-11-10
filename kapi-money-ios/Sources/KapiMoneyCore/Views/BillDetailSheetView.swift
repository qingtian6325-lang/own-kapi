import SwiftUI

public struct BillDetailSheetView: View {
    @ObservedObject public var store: KapiStore
    @State private var editableBill: TransactionItem
    public var onDismiss: () -> Void

    @State private var amountString: String
    @State private var discountString: String
    @State private var refundString: String

    public init(
        store: KapiStore,
        transaction: TransactionItem,
        onDismiss: @escaping () -> Void
    ) {
        self.store = store
        self._editableBill = State(initialValue: transaction)
        self.onDismiss = onDismiss
        self._amountString = State(initialValue: String(format: "%.2f", transaction.amount))
        self._discountString = State(
            initialValue: transaction.discountAmount > 0 ? String(format: "%.2f", transaction.discountAmount) : ""
        )
        self._refundString = State(
            initialValue: transaction.refundOrCashback.map { String(format: "%.2f", $0) } ?? ""
        )
    }

    public var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    // Main Amount & Category Card (IMG_2242)
                    VStack(spacing: 0) {
                        detailRow(label: "实付金额") {
                            HStack(spacing: 4) {
                                Text(editableBill.type == .expense ? "-RM" : "+RM")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(editableBill.type == .expense ? KapiTheme.expenseBlue : KapiTheme.incomeOrange)
                                TextField("0.00", text: $amountString)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(editableBill.type == .expense ? KapiTheme.expenseBlue : KapiTheme.incomeOrange)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 110)
                            }
                        }

                        Divider().padding(.leading, 16)

                        detailRow(label: "分类") {
                            Menu {
                                ForEach(store.expenseCategories) { group in
                                    if group.subcategories.isEmpty {
                                        Button(group.name) {
                                            editableBill.categoryPath = group.name
                                            editableBill.iconName = group.displayBadgeToken
                                        }
                                    } else {
                                        ForEach(group.subcategories) { sub in
                                            Button("\(group.name)-\(sub.name)") {
                                                editableBill.categoryPath = "\(group.name)-\(sub.name)"
                                                editableBill.iconName = sub.iconName
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    KapiStickerIconView(
                                        iconName: editableBill.iconName,
                                        categoryName: editableBill.categoryPath,
                                        transactionType: editableBill.type,
                                        size: 26
                                    )
                                    Text(editableBill.categoryPath)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(KapiTheme.textPrimary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(KapiTheme.textMuted)
                                }
                            }
                        }

                        Divider().padding(.leading, 16)

                        // Note + Receipt Photo Attachments (IMG_2242 & IMG_2243)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("备注")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(KapiTheme.textSecondary)
                                Spacer()
                                TextField("添加备注...", text: $editableBill.note)
                                    .font(.system(size: 14))
                                    .multilineTextAlignment(.trailing)
                            }

                            HStack(spacing: 10) {
                                ForEach(editableBill.receiptImageLabels, id: \.self) { label in
                                    ZStack(alignment: .topTrailing) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(hex: 0xEAF1FF))
                                            .frame(width: 58, height: 58)
                                            .overlay(
                                                VStack(spacing: 2) {
                                                    Image(systemName: "doc.text.image")
                                                        .font(.system(size: 18))
                                                        .foregroundColor(KapiTheme.expenseBlue)
                                                    Text(label)
                                                        .font(.system(size: 8))
                                                        .foregroundColor(KapiTheme.textSecondary)
                                                        .lineLimit(1)
                                                }
                                            )
                                    }
                                }

                                Button {
                                    editableBill.receiptImageLabels.append("小票_\(editableBill.receiptImageLabels.count + 1)")
                                } label: {
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .foregroundColor(KapiTheme.textMuted)
                                        .frame(width: 58, height: 58)
                                        .overlay(
                                            Image(systemName: "plus")
                                                .font(.system(size: 18))
                                                .foregroundColor(KapiTheme.textMuted)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))

                    // Time, Account & Ledger Card
                    VStack(spacing: 0) {
                        detailRow(label: "账单时间") {
                            DatePicker("", selection: $editableBill.date, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }

                        Divider().padding(.leading, 16)

                        detailRow(label: "付款账户") {
                            Menu {
                                Button("不选账户") { editableBill.accountName = "不选账户" }
                                ForEach(store.accounts) { acc in
                                    Button(acc.name) { editableBill.accountName = acc.name }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(editableBill.accountName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(KapiTheme.textPrimary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(KapiTheme.textMuted)
                                }
                            }
                        }

                        Divider().padding(.leading, 16)

                        detailRow(label: "所属账本") {
                            Text(editableBill.ledgerName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(KapiTheme.textPrimary)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))

                    // Discount, Refund/Cashback & Counterparty Card (IMG_2242 & IMG_2243)
                    VStack(spacing: 0) {
                        detailRow(label: "添加优惠") {
                            TextField("RM0.00", text: $discountString)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }

                        Divider().padding(.leading, 16)

                        detailRow(label: "添加退款/返现") {
                            TextField("RM0.00", text: $refundString)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }

                        Divider().padding(.leading, 16)

                        detailRow(label: "交易方") {
                            TextField("如：Eggette Lab / Jaya Grocer", text: $editableBill.counterparty)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))

                    // Save Changes Button
                    Button {
                        if let parsed = Double(amountString), parsed > 0 {
                            editableBill.amount = parsed
                        }
                        editableBill.discountAmount = Double(discountString) ?? 0.0
                        editableBill.refundOrCashback = Double(refundString)
                        store.updateTransaction(editableBill)
                        onDismiss()
                    } label: {
                        Text("保存修改")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(KapiTheme.expenseBlue))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .background(KapiTheme.background.ignoresSafeArea())
            .navigationTitle("账单详情")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(KapiTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.deleteTransaction(id: editableBill.id)
                        onDismiss()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KapiTheme.dangerRed)
                    }
                }
            }
        }
    }

    private func detailRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KapiTheme.textSecondary)
            Spacer()
            content()
        }
        .padding(16)
    }
}
