import SwiftUI

public struct BillDetailSheetView: View {
    @ObservedObject public var store: MimiStore
    @State private var editableBill: TransactionItem
    public var onDismiss: () -> Void

    @State private var amountString: String
    @State private var discountString: String
    @State private var refundString: String

    @State private var showAmountKeypad: Bool = false
    @State private var amountExpression: String = ""
    @State private var showingActionSheet = false
    @State private var showingImagePicker = false
    #if canImport(UIKit)
    @State private var pickerSourceType: UIKitImagePicker.SourceType = .photoLibrary
    #endif
    @State private var activeViewerItem: ReceiptViewerItem? = nil

    public init(
        store: MimiStore,
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
                        Button {
                            amountExpression = amountString
                            showAmountKeypad = true
                        } label: {
                            detailRow(label: "实付金额") {
                                HStack(spacing: 4) {
                                    Text(editableBill.type == .expense ? "-RM" : "+RM")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(editableBill.type == .expense ? MimiTheme.expenseBlue : MimiTheme.incomeOrange)
                                    Text(amountString.isEmpty ? "0.00" : amountString)
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(editableBill.type == .expense ? MimiTheme.expenseBlue : MimiTheme.incomeOrange)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(MimiTheme.textMuted)
                                }
                            }
                        }
                        .buttonStyle(.plain)

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
                                    MimiStickerIconView(
                                        iconName: editableBill.iconName,
                                        categoryName: editableBill.categoryPath,
                                        transactionType: editableBill.type,
                                        size: 26
                                    )
                                    Text(editableBill.categoryPath)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(MimiTheme.textPrimary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(MimiTheme.textMuted)
                                }
                            }
                        }

                        Divider().padding(.leading, 16)

                        // Note + Receipt Photo Attachments (IMG_2242 & IMG_2243)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("备注")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(MimiTheme.textSecondary)
                                Spacer()
                                TextField("添加备注...", text: $editableBill.note)
                                    .font(.system(size: 14))
                                    .multilineTextAlignment(.trailing)
                            }

                            // Real Image Thumbnails + Add Photo Button
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(editableBill.receiptImageLabels.enumerated()), id: \.offset) { idx, path in
                                        let imageData = store.loadReceiptImageData(filename: path)
                                        ZStack(alignment: .topTrailing) {
                                            Group {
                                                #if canImport(UIKit)
                                                if let data = imageData, let uiImage = UIImage(data: data) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 58, height: 58)
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                } else {
                                                    fallbackDocIcon(label: path)
                                                }
                                                #else
                                                fallbackDocIcon(label: path)
                                                #endif
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                if let data = imageData ?? store.loadReceiptImageData(filename: path) {
                                                    activeViewerItem = ReceiptViewerItem(imageData: data)
                                                }
                                            }

                                            // Delete receipt button
                                            Button {
                                                if idx < editableBill.receiptImageLabels.count {
                                                    let removed = editableBill.receiptImageLabels.remove(at: idx)
                                                    store.deleteReceiptImage(filename: removed)
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.65)))
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }

                                    Button {
                                        showingActionSheet = true
                                    } label: {
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                            .foregroundColor(MimiTheme.textMuted)
                                            .frame(width: 58, height: 58)
                                            .overlay(
                                                Image(systemName: "plus")
                                                    .font(.system(size: 20, weight: .medium))
                                                    .foregroundColor(MimiTheme.textMuted)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
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
                                        .foregroundColor(MimiTheme.textPrimary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(MimiTheme.textMuted)
                                }
                            }
                        }

                        Divider().padding(.leading, 16)

                        detailRow(label: "所属账本") {
                            HStack(spacing: 6) {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(MimiTheme.vipGold)
                                Text(editableBill.ledgerName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(MimiTheme.textPrimary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(MimiTheme.textMuted)
                            }
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
                            .background(Capsule().fill(MimiTheme.expenseBlue))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .background(MimiTheme.background.ignoresSafeArea())
            .navigationTitle("账单详情")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MimiTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.deleteTransaction(id: editableBill.id)
                        onDismiss()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MimiTheme.dangerRed)
                    }
                }
            }
            .confirmationDialog("添加小票或截图", isPresented: $showingActionSheet, titleVisibility: .visible) {
                #if canImport(UIKit)
                Button("📷 拍摄真实小票") {
                    pickerSourceType = .camera
                    showingImagePicker = true
                }
                Button("🖼️ 从相册选择小票/截图") {
                    pickerSourceType = .photoLibrary
                    showingImagePicker = true
                }
                #endif
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $showAmountKeypad) {
                amountKeypadSheet
                    .presentationDetents([.height(420)])
                    .presentationDragIndicator(.visible)
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showingImagePicker) {
                UIKitImagePicker(sourceType: pickerSourceType) { pickedImage in
                    if let data = pickedImage.jpegData(compressionQuality: 0.8) {
                        let filename = store.saveReceiptImage(data: data)
                        editableBill.receiptImageLabels.append(filename)
                    }
                }
            }
            #endif
            #if os(iOS)
            .fullScreenCover(item: $activeViewerItem) { item in
                FullscreenReceiptViewer(imageData: item.imageData) {
                    activeViewerItem = nil
                }
            }
            #else
            .sheet(item: $activeViewerItem) { item in
                FullscreenReceiptViewer(imageData: item.imageData) {
                    activeViewerItem = nil
                }
            }
            #endif
        }
    }

    // MARK: - 实付金额数字键盘（与记账页同风格）

    private var amountKeypadSheet: some View {
        let accent = editableBill.type == .expense ? MimiTheme.expenseBlue : MimiTheme.incomeOrange
        let rows: [[String]] = [
            ["7", "8", "9", "⌫"],
            ["4", "5", "6", "-"],
            ["1", "2", "3", "+"],
            ["清空", "0", ".", "完成"]
        ]

        return VStack(spacing: 16) {
            Capsule()
                .fill(Color(hex: 0xD8DCE6))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            Text("实付金额")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(MimiTheme.textSecondary)

            Text(amountExpression.isEmpty ? "RM0.00" : "RM\(amountExpression)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 20)

            VStack(spacing: 6) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { key in
                            Button {
                                handleAmountKey(key)
                            } label: {
                                Text(key)
                                    .font(.system(size: key == "完成" || key == "清空" ? 15 : 20, weight: .semibold, design: .rounded))
                                    .foregroundColor(key == "完成" ? .white : MimiTheme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(key == "完成" ? accent : Color.white)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color(hex: 0xF2F4F8))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color.white.ignoresSafeArea())
    }

    private func handleAmountKey(_ key: String) {
        switch key {
        case "⌫":
            if !amountExpression.isEmpty {
                amountExpression.removeLast()
            }
        case "清空":
            amountExpression = ""
        case "完成":
            let value = max(0.0, KeypadCalculator.evaluate(amountExpression))
            amountString = String(format: "%.2f", value)
            editableBill.amount = value
            showAmountKeypad = false
        default:
            amountExpression.append(key)
        }
    }

    private func fallbackDocIcon(label: String) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(hex: 0xEAF1FF))
            .frame(width: 58, height: 58)
            .overlay(
                VStack(spacing: 2) {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 18))
                        .foregroundColor(MimiTheme.expenseBlue)
                    Text(label)
                        .font(.system(size: 8))
                        .foregroundColor(MimiTheme.textSecondary)
                        .lineLimit(1)
                }
            )
    }

    private func detailRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(MimiTheme.textSecondary)
            Spacer()
            content()
        }
        .padding(16)
    }
}
