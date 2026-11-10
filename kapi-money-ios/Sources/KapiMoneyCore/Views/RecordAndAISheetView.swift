import SwiftUI

public struct RecordAndAISheetView: View {
    @ObservedObject public var store: KapiStore
    @ObservedObject public var aiEngine: KapiAIEngine
    public var initialAIMode: Bool
    public var onDismiss: () -> Void
    public var onOpenCategorySettings: () -> Void
    public var onEditRecognizedTransaction: (TransactionItem) -> Void

    @State private var isAIMode: Bool
    @State private var selectedTab: TransactionType = .expense
    @State private var selectedGroupIndex: Int = 0
    @State private var selectedSubIndex: Int? = 5 // defaults to 零食甜品 or first sub
    @State private var expression: String = ""
    @State private var noteText: String = ""
    @State private var selectedAccountName: String = "TNGewallet"
    @State private var targetAccountName: String = "PBBank"
    @State private var includeInStats: Bool = true
    @State private var discountAmountText: String = ""
    @State private var showDiscountInput: Bool = false
    @State private var selectedCurrency: CurrencyCode = .myr
    @State private var aiInputText: String = ""
    @State private var selectedDate: Date = Date()
    @State private var showDatePickerSheet: Bool = false
    @State private var selectedTags: [String] = []

    public init(
        store: KapiStore,
        aiEngine: KapiAIEngine,
        initialAIMode: Bool = false,
        onDismiss: @escaping () -> Void,
        onOpenCategorySettings: @escaping () -> Void,
        onEditRecognizedTransaction: @escaping (TransactionItem) -> Void
    ) {
        self.store = store
        self.aiEngine = aiEngine
        self.initialAIMode = initialAIMode
        self.onDismiss = onDismiss
        self.onOpenCategorySettings = onOpenCategorySettings
        self.onEditRecognizedTransaction = onEditRecognizedTransaction
        _isAIMode = State(initialValue: initialAIMode)
    }

    private var activeCategories: [CategoryGroup] {
        selectedTab == .income ? store.incomeCategories : store.expenseCategories
    }

    private var currentGroup: CategoryGroup? {
        guard !activeCategories.isEmpty else { return nil }
        let clamped = min(max(0, selectedGroupIndex), activeCategories.count - 1)
        return activeCategories[clamped]
    }

    private var evaluatedAmount: Double {
        KeypadCalculator.evaluate(expression)
    }

    private var composedCategoryPath: String {
        guard let group = currentGroup else { return "餐饮-零食甜品" }
        if let subIdx = selectedSubIndex, subIdx >= 0, subIdx < group.subcategories.count {
            return "\(group.name)-\(group.subcategories[subIdx].name)"
        }
        return group.name
    }

    private var currentIconName: String {
        guard let group = currentGroup else { return "food_snack" }
        if let subIdx = selectedSubIndex, subIdx >= 0, subIdx < group.subcategories.count {
            return group.subcategories[subIdx].iconName
        }
        return group.iconName
    }

    public var body: some View {
        VStack(spacing: 0) {
            sheetTopHeader
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if isAIMode {
                aiAssistantBody
            } else {
                manualBookkeepingBody
            }
        }
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showDatePickerSheet) {
            NavigationStack {
                VStack {
                    DatePicker("选择账单时间", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .padding()
                    Spacer()
                }
                .navigationTitle("选择账单时间")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showDatePickerSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Top Header with ⇄ Mode Switcher (IMG_2245 & IMG_2247)

    private var sheetTopHeader: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(KapiTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(hex: 0xF2F4F8)))
            }

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    isAIMode.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(isAIMode ? "手动记账" : "AI助手")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(KapiTheme.expenseBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: 0xE8F0FE)))
            }
            .buttonStyle(.plain)

            Spacer()

            if isAIMode {
                Text("任何事都能问我")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)
                Spacer()
                Color.clear.frame(width: 44, height: 32)
            } else {
                HStack(spacing: 18) {
                    ForEach(
                        [
                            (TransactionType.expense, "支出"),
                            (TransactionType.income, "收入"),
                            (TransactionType.transfer, "转账")
                        ],
                        id: \.0
                    ) { tab, titleText in
                        Button {
                            selectedTab = tab
                            selectedGroupIndex = 0
                            selectedSubIndex = 0
                        } label: {
                            VStack(spacing: 4) {
                                Text(titleText)
                                    .font(.system(size: 15, weight: selectedTab == tab ? .bold : .medium))
                                    .foregroundColor(selectedTab == tab ? KapiTheme.textPrimary : KapiTheme.textMuted)
                                Capsule()
                                    .fill(
                                        selectedTab == tab
                                            ? (tab == .income ? KapiTheme.incomeOrange : KapiTheme.expenseBlue)
                                            : Color.clear
                                    )
                                    .frame(width: 18, height: 3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Button(action: onOpenCategorySettings) {
                    Text("设置")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(KapiTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Manual Bookkeeping Mode (IMG_2245 & IMG_2246)

    private var manualBookkeepingBody: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    // 6-column Primary Category Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 12) {
                        ForEach(Array(activeCategories.enumerated()), id: \.element.id) { idx, group in
                            let isSelected = idx == selectedGroupIndex
                            Button {
                                selectedGroupIndex = idx
                                selectedSubIndex = group.subcategories.isEmpty ? nil : 0
                            } label: {
                                VStack(spacing: 5) {
                                    KapiStickerIconView(
                                        iconName: group.displayBadgeToken,
                                        categoryName: group.name,
                                        transactionType: selectedTab,
                                        useFirstCharIcon: group.useFirstCharIcon,
                                        size: 40,
                                        isSelected: isSelected
                                    )
                                    Text(group.name)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                                        .foregroundColor(isSelected ? KapiTheme.textPrimary : KapiTheme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 6)

                    // Expandable Subcategory Box (IMG_2245)
                    if let group = currentGroup, !group.subcategories.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(group.name) · 二级分类")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(KapiTheme.textMuted)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 10) {
                                ForEach(Array(group.subcategories.enumerated()), id: \.element.id) { sIdx, sub in
                                    let isSubSelected = selectedSubIndex == sIdx
                                    Button {
                                        selectedSubIndex = sIdx
                                    } label: {
                                        VStack(spacing: 4) {
                                            KapiStickerIconView(
                                                iconName: sub.iconName,
                                                categoryName: sub.name,
                                                transactionType: selectedTab,
                                                useFirstCharIcon: sub.useFirstCharIcon,
                                                size: 32,
                                                isSelected: isSubSelected
                                            )
                                            Text(sub.name)
                                                .font(.system(size: 10, weight: isSubSelected ? .bold : .regular))
                                                .foregroundColor(isSubSelected ? KapiTheme.expenseBlue : KapiTheme.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(hex: 0xF5F6FA))
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Divider()

            // Metadata Pills Row (不选账户 / TNGewallet | 11/08 16:59 | 优惠 | 选标签 | 多币种)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Menu {
                        Button("不选账户") { selectedAccountName = "不选账户" }
                        ForEach(store.accounts) { acc in
                            Button("\(acc.name) (\(KapiTheme.formatRM(acc.balance)))") {
                                selectedAccountName = acc.name
                            }
                        }
                    } label: {
                        pillLabel(icon: "creditcard", text: selectedAccountName)
                    }

                    if selectedTab == .transfer {
                        Menu {
                            ForEach(store.accounts) { acc in
                                Button("转入: \(acc.name)") {
                                    targetAccountName = acc.name
                                }
                            }
                        } label: {
                            pillLabel(icon: "arrow.right.circle", text: "转入 \(targetAccountName)")
                        }
                    }

                    Button {
                        showDatePickerSheet = true
                    } label: {
                        let f = DateFormatter()
                        let _ = { f.dateFormat = "MM/dd HH:mm" }()
                        pillLabel(icon: "calendar", text: f.string(from: selectedDate))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showDiscountInput.toggle()
                    } label: {
                        pillLabel(icon: "tag", text: discountAmountText.isEmpty ? "优惠" : "优惠 RM\(discountAmountText)")
                    }
                    .buttonStyle(.plain)

                    Button {
                        includeInStats.toggle()
                    } label: {
                        pillLabel(
                            icon: includeInStats ? "checkmark.circle.fill" : "slash.circle",
                            text: includeInStats ? "计入收支" : "不计入收支"
                        )
                    }
                    .buttonStyle(.plain)

                    Menu {
                        ForEach(store.tags, id: \.self) { tag in
                            Button {
                                if selectedTags.contains(tag) {
                                    selectedTags.removeAll(where: { $0 == tag })
                                } else {
                                    selectedTags.append(tag)
                                }
                            } label: {
                                if selectedTags.contains(tag) {
                                    Label(tag, systemImage: "checkmark")
                                } else {
                                    Text(tag)
                                }
                            }
                        }
                    } label: {
                        pillLabel(icon: "number", text: selectedTags.isEmpty ? "选标签" : selectedTags.joined(separator: ","))
                    }

                    Menu {
                        ForEach(CurrencyCode.allCases, id: \.self) { code in
                            Button(code.rawValue) { selectedCurrency = code }
                        }
                    } label: {
                        pillLabel(icon: "globe", text: "多币种 (\(selectedCurrency.rawValue))")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // Amount + Note Row (RM0.00 MYR ⌄ + 点此输入备注...)
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(composedCategoryPath)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(KapiTheme.textSecondary)

                    Spacer()

                    Text(expression.isEmpty ? "RM0.00" : "RM\(expression)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(selectedTab == .income ? KapiTheme.incomeOrange : KapiTheme.expenseBlue)

                    Text("\(selectedCurrency.rawValue) ⌄")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(KapiTheme.textMuted)
                }

                HStack(spacing: 10) {
                    TextField("点此输入备注...", text: $noteText)
                        .font(.system(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))

                    Button {
                        #if canImport(UIKit)
                        if let image = UIPasteboard.general.image, let pngData = image.pngData() {
                            let draft = ReceiptOCRService.recognizeAndParseImageSync(pngData)
                            if draft.amount > 0 {
                                expression = String(format: "%.2f", draft.amount)
                            }
                            if !draft.note.isEmpty && draft.note != "快捷记账" {
                                noteText = draft.note
                            }
                            if !draft.accountName.isEmpty {
                                selectedAccountName = draft.accountName
                            }
                            if !draft.categoryDisplayName.isEmpty {
                                selectedCategory = draft.categoryDisplayName
                            }
                        } else if let clip = UIPasteboard.general.string, !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let draft = ReceiptOCRService.parseReceiptText(clip)
                            if draft.amount > 0 {
                                expression = String(format: "%.2f", draft.amount)
                            }
                            if !draft.note.isEmpty && draft.note != "快捷记账" {
                                noteText = draft.note
                            }
                            if !draft.accountName.isEmpty {
                                selectedAccountName = draft.accountName
                            }
                            if !draft.categoryDisplayName.isEmpty {
                                selectedCategory = draft.categoryDisplayName
                            }
                        }
                        #endif
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 15))
                            .foregroundColor(KapiTheme.expenseBlue)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xE8F0FE)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Custom Calculator Keypad (IMG_2245)
            calculatorKeypad
        }
    }

    private func pillLabel(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(KapiTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color(hex: 0xF2F4F8)))
    }

    private var calculatorKeypad: some View {
        let rows: [[String]] = [
            ["7", "8", "9", "⌫"],
            ["4", "5", "6", "-"],
            ["1", "2", "3", "+"],
            ["再记", "0", ".", "完成"]
        ]

        return VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleKeyTap(key)
                        } label: {
                            Text(key)
                                .font(.system(size: key == "完成" || key == "再记" ? 15 : 20, weight: .semibold, design: .rounded))
                                .foregroundColor(key == "完成" ? .white : KapiTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            key == "完成"
                                                ? (selectedTab == .income ? KapiTheme.incomeOrange : KapiTheme.expenseBlue)
                                                : Color.white
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .background(Color(hex: 0xF2F4F8))
    }

    private func handleKeyTap(_ key: String) {
        switch key {
        case "⌫":
            if !expression.isEmpty {
                expression.removeLast()
            }
        case "再记":
            saveManualTransaction(dismissAfter: false)
        case "完成":
            saveManualTransaction(dismissAfter: true)
        default:
            expression.append(key)
        }
    }

    private func saveManualTransaction(dismissAfter: Bool) {
        let finalAmount = max(0.0, evaluatedAmount)
        guard finalAmount > 0 else {
            if dismissAfter { onDismiss() }
            return
        }
        let discountVal = Double(discountAmountText) ?? 0.0
        let tx = TransactionItem(
            type: selectedTab,
            categoryPath: selectedTab == .transfer ? "转账" : composedCategoryPath,
            iconName: selectedTab == .transfer ? "⇄" : currentIconName,
            amount: finalAmount,
            accountName: selectedAccountName,
            targetAccountName: selectedTab == .transfer ? targetAccountName : nil,
            note: noteText,
            discountAmount: discountVal,
            includeInStats: selectedTab == .transfer ? false : includeInStats,
            tags: selectedTags,
            date: selectedDate
        )
        store.addTransaction(tx)
        expression = ""
        noteText = ""
        discountAmountText = ""
        selectedTags = []
        if dismissAfter {
            onDismiss()
        }
    }

    // MARK: - AI Assistant Mode (IMG_2247 & IMG_2248)

    private var aiAssistantBody: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(aiEngine.messages) { msg in
                        chatBubbleView(for: msg)
                    }
                }
                .padding(16)
            }
            .background(KapiTheme.background)

            // Quick Prompt Chips (有哪些分类 | 怎么记退款 | 怎么记报销 | 一句话记多笔)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["有哪些分类", "怎么记退款", "怎么记报销", "一句话记多笔", "识别付款截图"], id: \.self) { chip in
                        Button {
                            if chip == "一句话记多笔" {
                                aiEngine.handleUserMessage("午饭 24.5 咖啡 12.9 打车 18", store: store)
                            } else if chip == "识别付款截图" {
                                let draft = ReceiptOCRService.parseReceiptText(
                                    "-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34"
                                )
                                aiEngine.messages.append(
                                    AIChatMessage(isUser: false, blocks: [.draftBills([draft])])
                                )
                            } else {
                                aiEngine.handleUserMessage(chip, store: store)
                            }
                        } label: {
                            Text(chip)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KapiTheme.expenseBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color(hex: 0xE8F0FE)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color.white)

            // Bottom Input Bar
            HStack(spacing: 10) {
                TextField("点此输入文字（如：早茶15 地铁4.5）", text: $aiInputText)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: 0xF5F6FA)))

                Button {
                    guard !aiInputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let prompt = aiInputText
                    aiInputText = ""
                    aiEngine.handleUserMessage(prompt, store: store)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(KapiTheme.expenseBlue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .background(Color.white)
        }
    }

    @ViewBuilder
    private func chatBubbleView(for message: AIChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer()
            } else {
                ZStack {
                    Circle().fill(Color(hex: 0xFFE8CC)).frame(width: 30, height: 30)
                    Text("🦫").font(.system(size: 16))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(message.blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .text(let text):
                        Text(text)
                            .font(.system(size: 14))
                            .foregroundColor(message.isUser ? .white : KapiTheme.textPrimary)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(message.isUser ? KapiTheme.expenseBlue : Color.white)
                            )

                    case .categoryTable(let expenseRows, let incomeRows, let customNote):
                        VStack(alignment: .leading, spacing: 10) {
                            categoryTableBox(rows: expenseRows)

                            if !incomeRows.isEmpty {
                                Text("标准收入分类如下：")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(KapiTheme.textPrimary)
                                    .padding(.top, 4)
                                categoryTableBox(rows: incomeRows)
                            }

                            if !customNote.isEmpty {
                                Text(customNote)
                                    .font(.system(size: 12))
                                    .foregroundColor(KapiTheme.textSecondary)
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))

                    case .spendingSummary(let title, let amount, let count, let details):
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(KapiTheme.textPrimary)
                            Text("总支出 \(KapiTheme.formatRM(amount)) · 共 \(count) 笔")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(KapiTheme.expenseBlue)
                            Text(details)
                                .font(.system(size: 12))
                                .foregroundColor(KapiTheme.textSecondary)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))

                    case .draftBills(let drafts):
                        VStack(spacing: 10) {
                            ForEach(drafts) { draft in
                                let tempTx = TransactionItem(
                                    type: draft.type,
                                    categoryPath: draft.categoryPath,
                                    iconName: draft.iconName,
                                    amount: draft.amount,
                                    accountName: draft.accountName,
                                    note: draft.note,
                                    date: draft.date
                                )
                                ScreenshotResultSnippetView(
                                    transaction: tempTx,
                                    onModifyTapped: {
                                        let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
                                        onEditRecognizedTransaction(saved)
                                    },
                                    onConfirmTapped: {
                                        _ = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
                                    }
                                )
                            }
                        }
                    }
                }
            }

            if !message.isUser {
                Spacer(minLength: 12)
            }
        }
    }

    private func categoryTableBox(rows: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("一级分类")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 82, alignment: .leading)
                Text("二级分类")
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(Color(hex: 0xF2F4F8))

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top) {
                    Text(row.0)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(KapiTheme.textPrimary)
                        .frame(width: 82, alignment: .leading)
                    Text(row.1)
                        .font(.system(size: 12))
                        .foregroundColor(KapiTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                Divider()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: 0xE6E8F0), lineWidth: 1)
        )
    }
}
