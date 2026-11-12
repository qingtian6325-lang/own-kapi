import SwiftUI

public struct RecordAndAISheetView: View {
    @ObservedObject public var store: MimiStore
    @ObservedObject public var aiEngine: MimiAIEngine
    public var initialAIMode: Bool
    public var onDismiss: () -> Void
    public var onOpenCategorySettings: () -> Void
    public var onEditRecognizedTransaction: (TransactionItem) -> Void
    public var onOpenImportExport: () -> Void = {}

    @State private var isAIMode: Bool
    @State private var selectedTab: TransactionType = .expense
    @State private var selectedGroupIndex: Int = 0
    @State private var selectedSubIndex: Int? = 5 // defaults to 零食甜品 or first sub
    @State private var expression: String = ""
    @State private var noteText: String = ""
    @State private var selectedAccountName: String = "不选账户"
    @State private var targetAccountName: String = ""
    @State private var includeInStats: Bool = true
    @State private var includeInBudget: Bool = true
    @State private var markPendingReimbursement: Bool = false
    @State private var discountAmountText: String = ""
    @State private var showDiscountInput: Bool = false
    @State private var selectedCurrency: CurrencyCode = .myr
    @State private var aiInputText: String = ""
    @State private var selectedDate: Date = Date()
    @State private var showDatePickerSheet: Bool = false
    @State private var selectedTags: [String] = []
    @State private var attachedReceiptFilenames: [String] = []
    @State private var showImageSourceDialog: Bool = false
    @State private var showImagePickerSheet: Bool = false
    #if canImport(UIKit)
    @State private var pickerSourceType: UIKitImagePicker.SourceType = .photoLibrary
    #endif
    @State private var activeViewerItem: ReceiptViewerItem? = nil
    @State private var showChatAttachmentPanel: Bool = false
    @State private var showChatAlbumPicker: Bool = false
    @State private var showChatCameraPicker: Bool = false
    @State private var recognitionFailureText: String?
    #if canImport(Speech) && canImport(AVFoundation)
    @StateObject private var speechTranscriber = SpeechTranscriber()
    #endif

    public init(
        store: MimiStore,
        aiEngine: MimiAIEngine,
        initialAIMode: Bool = false,
        onDismiss: @escaping () -> Void,
        onOpenCategorySettings: @escaping () -> Void,
        onEditRecognizedTransaction: @escaping (TransactionItem) -> Void,
        onOpenImportExport: @escaping () -> Void = {}
    ) {
        self.store = store
        self.aiEngine = aiEngine
        self.initialAIMode = initialAIMode
        self.onDismiss = onDismiss
        self.onOpenCategorySettings = onOpenCategorySettings
        self.onEditRecognizedTransaction = onEditRecognizedTransaction
        self.onOpenImportExport = onOpenImportExport
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
            if isAIMode {
                aiChatTopHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                aiAssistantBody
            } else {
                sheetTopHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
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
        .confirmationDialog("添加小票并自动识别", isPresented: $showImageSourceDialog, titleVisibility: .visible) {
            #if canImport(UIKit)
            Button("📷 拍照真实小票") {
                pickerSourceType = .camera
                showImagePickerSheet = true
            }
            Button("🖼️ 从相册选择小票/截图") {
                pickerSourceType = .photoLibrary
                showImagePickerSheet = true
            }
            Button("📋 识别剪贴板图片") {
                readFromClipboard()
            }
            #endif
            Button("取消", role: .cancel) {}
        }
        .alert("AI 识别失败", isPresented: Binding(
            get: { recognitionFailureText != nil },
            set: { if !$0 { recognitionFailureText = nil } }
        )) {
            Button("好") { recognitionFailureText = nil }
        } message: {
            Text(recognitionFailureText ?? "")
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showImagePickerSheet) {
            UIKitImagePicker(sourceType: pickerSourceType) { pickedImage in
                if let data = pickedImage.jpegData(compressionQuality: 0.8) {
                    let filename = store.saveReceiptImage(data: data)
                    attachedReceiptFilenames.append(filename)
                    Task {
                        do {
                            let result = try await SmartReceiptRecognizer.recognize(imageData: data)
                            await MainActor.run {
                                applyDraft(result.draft)
                            }
                        } catch {
                            await MainActor.run {
                                recognitionFailureText = recognitionDialogText(for: error)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showChatAlbumPicker) {
            PHPickerImageView { imageData in
                recognizeChatImage(imageData, sourceLabel: "相册")
            }
        }
        .sheet(isPresented: $showChatCameraPicker) {
            UIKitImagePicker(sourceType: .camera) { pickedImage in
                if let data = pickedImage.jpegData(compressionQuality: 0.85) {
                    recognizeChatImage(data, sourceLabel: "拍照")
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

    // MARK: - Top Header with ⇄ Mode Switcher (IMG_2245 & IMG_2247)

    // MARK: - AI Chat Header (Kapi 布局：[猫头像] 记账查账，问问题 [⇌ 手动记账] [✕])

    private var aiChatTopHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color(hex: 0xFFE8CC)).frame(width: 34, height: 34)
                Text("🐱").font(.system(size: 18))
            }

            Text("记账查账，问问题")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(MimiTheme.textPrimary)

            Spacer()

            Button {
                aiEngine.clearHistory()
            } label: {
                Text("清空")
                    .font(.system(size: 12))
                    .foregroundColor(MimiTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    isAIMode = false
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .bold))
                    Text("手动记账")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(MimiTheme.expenseBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().strokeBorder(Color(hex: 0xD8DEEA), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(MimiTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(hex: 0xF2F4F8)))
            }
            .buttonStyle(.plain)
        }
    }

    /// 聊天层相册/拍照选图后：纯 AI（Gemini）识别，草稿进聊天等确认；
    /// 失败时在聊天里如实说明原因，不生成草稿、不落账，可重试。
    private func recognizeChatImage(_ imageData: Data, sourceLabel: String) {
        showChatAttachmentPanel = false
        Task {
            do {
                let result = try await SmartReceiptRecognizer.recognize(imageData: imageData)
                await MainActor.run {
                    aiEngine.appendRecognizedDraft(
                        result.draft,
                        sourceLabel: sourceLabel,
                        isSuspiciousAmount: result.isSuspiciousAmount
                    )
                }
            } catch {
                await MainActor.run {
                    aiEngine.appendRecognitionFailure(recognitionDialogText(for: error), sourceLabel: sourceLabel)
                }
            }
        }
    }

    /// 把识别失败统一换成给用户看的中文说明。
    private func recognitionDialogText(for error: Error) -> String {
        (error as? ReceiptRecognitionFailure)?.dialogText
            ?? ReceiptRecognitionFailure.failed(reason: error.localizedDescription).dialogText
    }

    private var sheetTopHeader: some View {
        HStack(spacing: 10) {
            if isAIMode {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(MimiTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(hex: 0xF2F4F8)))
                }
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        isAIMode = false
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 14, weight: .bold))
                        Text("手动记账")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(MimiTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().strokeBorder(Color(hex: 0xD8DEEA), lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
                Text("任何事都能问我")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
                Color.clear.frame(width: 44, height: 32)
            } else {
                // Gold: 支出 | 收入 | 转账 ····· AI 助手 · ✕
                HStack(spacing: 16) {
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
                                    .foregroundColor(
                                        selectedTab == tab
                                            ? (tab == .income ? MimiTheme.incomeOrange : MimiTheme.expenseBlue)
                                            : MimiTheme.textMuted
                                    )
                                Capsule()
                                    .fill(
                                        selectedTab == tab
                                            ? (tab == .income ? MimiTheme.incomeOrange : MimiTheme.expenseBlue)
                                            : Color.clear
                                    )
                                    .frame(width: 18, height: 3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        isAIMode = true
                    }
                } label: {
                    Text("AI 助手")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MimiTheme.expenseBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(hex: 0xE8F0FE)))
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MimiTheme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color(hex: 0xF2F4F8)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Manual Bookkeeping Mode (IMG_2245 & IMG_2246)

    private var manualBookkeepingBody: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if selectedTab == .transfer {
                        transferAccountPicker
                            .padding(.top, 10)
                    } else {
                        // 5-column Primary Category Grid (gold manual entry)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 12) {
                            ForEach(Array(activeCategories.enumerated()), id: \.element.id) { idx, group in
                                let isSelected = idx == selectedGroupIndex
                                Button {
                                    selectedGroupIndex = idx
                                    selectedSubIndex = group.subcategories.isEmpty ? nil : 0
                                } label: {
                                    VStack(spacing: 6) {
                                        MimiStickerIconView(
                                            iconName: group.displayBadgeToken,
                                            categoryName: group.name,
                                            transactionType: selectedTab,
                                            useFirstCharIcon: group.useFirstCharIcon,
                                            size: 58,
                                            isSelected: isSelected
                                        )
                                        Text(group.name)
                                            .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                            .foregroundColor(isSelected ? MimiTheme.textPrimary : MimiTheme.textSecondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)
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
                                    .foregroundColor(MimiTheme.textMuted)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 10) {
                                    ForEach(Array(group.subcategories.enumerated()), id: \.element.id) { sIdx, sub in
                                        let isSubSelected = selectedSubIndex == sIdx
                                        Button {
                                            selectedSubIndex = sIdx
                                        } label: {
                                            VStack(spacing: 5) {
                                                MimiStickerIconView(
                                                    iconName: sub.iconName,
                                                    categoryName: sub.name,
                                                    transactionType: selectedTab,
                                                    useFirstCharIcon: sub.useFirstCharIcon,
                                                    size: 48,
                                                    isSelected: isSubSelected
                                                )
                                                Text(sub.name)
                                                    .font(.system(size: 11, weight: isSubSelected ? .bold : .regular))
                                                    .foregroundColor(isSubSelected ? MimiTheme.expenseBlue : MimiTheme.textSecondary)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.85)
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
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Divider()

            // Gold pills: 日期 · 账本 · 无账户 · 优惠 / 待报销 · 计入收支 · 计入预算 · 标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        showDatePickerSheet = true
                    } label: {
                        let f = DateFormatter()
                        let _ = { f.dateFormat = "M月d日" }()
                        pillLabel(icon: "calendar", text: f.string(from: selectedDate))
                    }
                    .buttonStyle(.plain)

                    if selectedTab != .transfer {
                        Menu {
                            ForEach(store.ledgers) { ledger in
                                Button(ledger.name) {
                                    store.currentLedgerName = ledger.name
                                }
                            }
                        } label: {
                            let ledgerName = store.currentLedgerName
                            let short = ledgerName.count > 6 ? String(ledgerName.prefix(4)) + "…" : ledgerName
                            pillLabel(icon: "book.closed", text: short.isEmpty ? "Main…" : short)
                        }

                        Menu {
                            Button("不选账户") { selectedAccountName = "不选账户" }
                            ForEach(store.accounts) { acc in
                                Button("\(acc.name) (\(MimiTheme.formatRM(acc.balance)))") {
                                    selectedAccountName = acc.name
                                }
                            }
                        } label: {
                            pillLabel(icon: "creditcard", text: selectedAccountName == "不选账户" ? "无账户" : selectedAccountName)
                        }

                        Button {
                            showDiscountInput.toggle()
                        } label: {
                            pillLabel(icon: "tag", text: discountAmountText.isEmpty ? "优惠" : "优惠 RM\(discountAmountText)")
                        }
                        .buttonStyle(.plain)

                        Button {
                            markPendingReimbursement.toggle()
                        } label: {
                            pillLabel(
                                icon: markPendingReimbursement ? "checkmark.circle.fill" : "clock",
                                text: "待报销"
                            )
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

                        Button {
                            includeInBudget.toggle()
                        } label: {
                            pillLabel(
                                icon: includeInBudget ? "checkmark.circle.fill" : "slash.circle",
                                text: includeInBudget ? "计入预算" : "不计入预算"
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
                            pillLabel(icon: "number", text: selectedTags.isEmpty ? "标签" : selectedTags.joined(separator: ","))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // Amount + Note Row (gold: RM0.00 + MYR ⌄, 点击填写备注信息 + 相册/拍照)
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(expression.isEmpty ? "RM0.00" : "RM\(expression)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(selectedTab == .income ? MimiTheme.incomeOrange : MimiTheme.expenseBlue)

                    Menu {
                        ForEach(CurrencyCode.allCases, id: \.self) { code in
                            Button(code.rawValue) { selectedCurrency = code }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text(selectedCurrency.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(MimiTheme.textMuted)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)

                HStack(spacing: 8) {
                    TextField("点击填写备注信息", text: $noteText)
                        .font(.system(size: 14))
                        .foregroundColor(MimiTheme.textPrimary)

                    Button {
                        showImageSourceDialog = true
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: 0x9AA0B0))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showImageSourceDialog = true
                    } label: {
                        Image(systemName: "camera")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: 0x9AA0B0))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: 0xF5F6FA)))
                .padding(.horizontal, 16)

                if !attachedReceiptFilenames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(attachedReceiptFilenames.enumerated()), id: \.offset) { idx, path in
                                let data = store.loadReceiptImageData(filename: path)
                                ZStack(alignment: .topTrailing) {
                                    Group {
                                        #if canImport(UIKit)
                                        if let d = data, let img = UIImage(data: d) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 48, height: 48)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(hex: 0xEAF1FF))
                                                .frame(width: 48, height: 48)
                                        }
                                        #else
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hex: 0xEAF1FF))
                                            .frame(width: 48, height: 48)
                                        #endif
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if let d = data ?? store.loadReceiptImageData(filename: path) {
                                            activeViewerItem = ReceiptViewerItem(imageData: d)
                                        }
                                    }

                                    Button {
                                        if idx < attachedReceiptFilenames.count {
                                            let removed = attachedReceiptFilenames.remove(at: idx)
                                            store.deleteReceiptImage(filename: removed)
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.65)))
                                    }
                                    .offset(x: 3, y: -3)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Custom Calculator Keypad (IMG_2245)
            calculatorKeypad
        }
    }

    /// Gold transfer: 扣款账户 ⇄ 入款账户
    private var transferAccountPicker: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(store.accounts) { acc in
                    Button(acc.name) { selectedAccountName = acc.name }
                }
            } label: {
                transferAccountBox(
                    title: selectedAccountName.isEmpty || selectedAccountName == "不选账户" ? "扣款账户" : selectedAccountName,
                    subtitle: selectedAccountName.isEmpty || selectedAccountName == "不选账户" ? "选择转出" : "扣款账户"
                )
            }

            Button {
                let from = selectedAccountName
                selectedAccountName = targetAccountName
                targetAccountName = from
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(MimiTheme.expenseBlue)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(hex: 0xE8F0FE)))
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(store.accounts) { acc in
                    Button(acc.name) { targetAccountName = acc.name }
                }
            } label: {
                transferAccountBox(
                    title: targetAccountName.isEmpty ? "入款账户" : targetAccountName,
                    subtitle: targetAccountName.isEmpty ? "选择转入" : "入款账户"
                )
            }
        }
    }

    private func transferAccountBox(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "creditcard")
                .font(.system(size: 22))
                .foregroundColor(MimiTheme.textSecondary)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(MimiTheme.textPrimary)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(MimiTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0xF5F6FA)))
    }

    private func pillLabel(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(MimiTheme.textSecondary)
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
                                .foregroundColor(key == "完成" ? .white : MimiTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            key == "完成"
                                                ? (selectedTab == .income ? MimiTheme.incomeOrange : MimiTheme.expenseBlue)
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
        var tags = selectedTags
        if markPendingReimbursement, !tags.contains("待报销") {
            tags.append("待报销")
        }
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
            includeInBudget: selectedTab == .transfer ? false : includeInBudget,
            tags: tags,
            receiptImageLabels: attachedReceiptFilenames,
            date: selectedDate
        )
        store.addTransaction(tx)
        expression = ""
        noteText = ""
        discountAmountText = ""
        selectedTags = []
        attachedReceiptFilenames = []
        markPendingReimbursement = false
        includeInBudget = true
        if dismissAfter {
            onDismiss()
        }
    }

    private func readFromClipboard() {
        #if canImport(UIKit)
        if let image = UIPasteboard.general.image, let pngData = image.pngData() {
            let filename = store.saveReceiptImage(data: pngData)
            attachedReceiptFilenames.append(filename)
            Task {
                do {
                    let result = try await SmartReceiptRecognizer.recognize(imageData: pngData)
                    await MainActor.run {
                        applyDraft(result.draft)
                    }
                } catch {
                    await MainActor.run {
                        recognitionFailureText = recognitionDialogText(for: error)
                    }
                }
            }
        } else {
            recognitionFailureText = "剪贴板里没有图片。AI 识别需要付款截图或收据照片，请先截屏、或把图片复制到剪贴板后再试。"
        }
        #endif
    }

    private func applyDraft(_ draft: ParsedDraftBill) {
        if draft.amount > 0 {
            expression = String(format: "%.2f", draft.amount)
        }
        if !draft.note.isEmpty && draft.note != "快捷记账" {
            noteText = draft.note
        }
        if !draft.accountName.isEmpty {
            selectedAccountName = draft.accountName
        }
        selectedDate = draft.date
        if draft.type == .income {
            selectedTab = .income
        } else {
            selectedTab = .expense
        }
        if let grpIdx = activeCategories.firstIndex(where: { $0.id == draft.primaryCategoryId || $0.name == draft.primaryCategoryId }) {
            selectedGroupIndex = grpIdx
            if let subId = draft.subCategoryId,
               let subIdx = activeCategories[grpIdx].subcategories.firstIndex(where: { $0.id == subId || $0.name == subId }) {
                selectedSubIndex = subIdx
            } else if !activeCategories[grpIdx].subcategories.isEmpty {
                selectedSubIndex = 0
            }
        }
    }

    // MARK: - AI Assistant Mode (IMG_2247 & IMG_2248)

    private var aiAssistantBody: some View {
        VStack(spacing: 0) {
            // 示例问题：空状态时放在欢迎语下方，更像聊天引导
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if aiEngine.messages.isEmpty {
                            HStack(alignment: .top, spacing: 10) {
                                MimiAskMascotView(size: 34)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("你好，我是咪咪")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(MimiTheme.textPrimary)
                                    Text("直接说「午餐 38」就能记账，也可以问「本月花了多少」「哪一笔最贵」。")
                                        .font(.system(size: 14))
                                        .foregroundColor(MimiTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(14)
                                .background(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 4,
                                        bottomLeadingRadius: 18,
                                        bottomTrailingRadius: 18,
                                        topTrailingRadius: 18,
                                        style: .continuous
                                    )
                                    .fill(Color.white)
                                )
                                Spacer(minLength: 20)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("试试这样问")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(MimiTheme.textMuted)
                                    .padding(.leading, 4)
                                ForEach(MimiAIEngine.exampleQuestions, id: \.self) { question in
                                    Button {
                                        aiEngine.handleUserMessage(question, store: store)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(MimiTheme.expenseBlue)
                                            Text(question)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(MimiTheme.textPrimary)
                                                .multilineTextAlignment(.leading)
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color.white)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color(hex: 0xE8ECF4), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.leading, 44)
                        }

                        ForEach(aiEngine.messages) { msg in
                            chatBubbleView(for: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 8)
                }
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0xF3F6FC), MimiTheme.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .onChange(of: aiEngine.messages.count) { _, _ in
                    if let last = aiEngine.messages.last {
                        withAnimation(.easeOut(duration: 0.22)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Quick Prompt Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["有哪些分类", "怎么记退款", "怎么记报销", "一句话记多笔"], id: \.self) { chip in
                        Button {
                            if chip == "一句话记多笔" {
                                aiEngine.handleUserMessage("午饭 24.5 咖啡 12.9 打车 18", store: store)
                            } else {
                                aiEngine.handleUserMessage(chip, store: store)
                            }
                        } label: {
                            Text(chip)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(MimiTheme.expenseBlue)
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
            .background(Color.white.opacity(0.96))

            if showChatAttachmentPanel {
                AIAttachmentPanelView(
                    onPickFromAlbum: { showChatAlbumPicker = true },
                    onTakePhoto: { showChatCameraPicker = true },
                    onOpenImportExport: {
                        showChatAttachmentPanel = false
                        onOpenImportExport()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .background(Color.white)
            }

            #if canImport(Speech) && canImport(AVFoundation)
            if speechTranscriber.isRecording {
                Text("正在聆听：\(speechTranscriber.partialText)")
                    .font(.system(size: 12))
                    .foregroundColor(MimiTheme.expenseBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .background(Color.white)
            } else if !speechTranscriber.statusText.isEmpty {
                Text(speechTranscriber.statusText)
                    .font(.system(size: 12))
                    .foregroundColor(MimiTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .background(Color.white)
            }
            #endif

            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        showChatAttachmentPanel.toggle()
                    }
                } label: {
                    Image(systemName: showChatAttachmentPanel ? "xmark" : "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(MimiTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(hex: 0xF0F2F7)))
                }
                .buttonStyle(.plain)

                TextField("发消息或按住说话…", text: $aiInputText)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(hex: 0xF5F6FA))
                    )

                #if canImport(Speech) && canImport(AVFoundation)
                if aiInputText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Image(systemName: speechTranscriber.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(speechTranscriber.isRecording ? MimiTheme.dangerRed : MimiTheme.textMuted)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 60, pressing: { isPressing in
                            if isPressing {
                                Task {
                                    if await speechTranscriber.requestAuthorization() {
                                        speechTranscriber.startRecording()
                                    }
                                }
                            } else if speechTranscriber.isRecording {
                                let recognized = speechTranscriber.stopRecording()
                                if !recognized.trimmingCharacters(in: .whitespaces).isEmpty {
                                    aiInputText = recognized
                                }
                            }
                        }, perform: {})
                }
                #endif

                Button {
                    let prompt = aiInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !prompt.isEmpty else { return }
                    aiInputText = ""
                    aiEngine.handleUserMessage(prompt, store: store)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(
                                aiInputText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color(hex: 0xC5CCD8)
                                    : MimiTheme.expenseBlue
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(aiInputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background(Color.white)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(hex: 0xE8ECF4))
                    .frame(height: 1)
            }
        }
    }

    /// 聊天里的账单草稿卡：确认记账 / 取消，确认才入账。
    private func chatDraftCard(message: AIChatMessage, drafts: [ParsedDraftBill]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(drafts) { draft in
                HStack(spacing: 10) {
                    Text(draft.iconName)
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(draft.categoryPath)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MimiTheme.textPrimary)
                        Text("\(draft.accountName) · \(draft.note)")
                            .font(.system(size: 12))
                            .foregroundColor(MimiTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text((draft.type == .income ? "+" : "-") + MimiTheme.formatRM(draft.amount))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(draft.type == .income ? MimiTheme.incomeOrange : MimiTheme.expenseBlue)
                }
            }

            HStack(spacing: 10) {
                Button {
                    aiEngine.cancelDrafts(messageId: message.id)
                } label: {
                    Text("取消")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MimiTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color(hex: 0xF2F4F8)))
                }
                .buttonStyle(.plain)

                Button {
                    aiEngine.confirmDrafts(messageId: message.id, in: store)
                } label: {
                    Text("确认记账")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(MimiTheme.expenseBlue))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
    }

    @ViewBuilder
    private func chatBubbleView(for message: AIChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 36)
            } else {
                MimiAskMascotView(size: 30)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 10) {
                ForEach(Array(message.blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .pendingAnswer:
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在查账…")
                                .font(.system(size: 14))
                                .foregroundColor(MimiTheme.textSecondary)
                        }
                        .padding(12)
                        .background(chatBubbleShape(isUser: false).fill(Color.white))

                    case .text(let text):
                        Text(text)
                            .font(.system(size: 14))
                            .foregroundColor(message.isUser ? .white : MimiTheme.textPrimary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 11)
                            .background(
                                chatBubbleShape(isUser: message.isUser)
                                    .fill(message.isUser ? MimiTheme.expenseBlue : Color.white)
                            )

                    case .categoryTable(let expenseRows, let incomeRows, let customNote):
                        VStack(alignment: .leading, spacing: 10) {
                            categoryTableBox(rows: expenseRows)

                            if !incomeRows.isEmpty {
                                Text("标准收入分类如下：")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(MimiTheme.textPrimary)
                                    .padding(.top, 4)
                                categoryTableBox(rows: incomeRows)
                            }

                            if !customNote.isEmpty {
                                Text(customNote)
                                    .font(.system(size: 12))
                                    .foregroundColor(MimiTheme.textSecondary)
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))

                    case .spendingSummary(let title, let amount, let count, let details):
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(MimiTheme.textPrimary)
                            Text("总支出 \(MimiTheme.formatRM(amount)) · 共 \(count) 笔")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(MimiTheme.expenseBlue)
                            Text(details)
                                .font(.system(size: 12))
                                .foregroundColor(MimiTheme.textSecondary)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))

                    case .draftBills(let drafts):
                        chatDraftCard(message: message, drafts: drafts)
                    }
                }
            }

            if !message.isUser {
                Spacer(minLength: 28)
            }
        }
    }

    private func chatBubbleShape(isUser: Bool) -> UnevenRoundedRectangle {
        if isUser {
            return UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 18,
                topTrailingRadius: 4,
                style: .continuous
            )
        }
        return UnevenRoundedRectangle(
            topLeadingRadius: 4,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 18,
            topTrailingRadius: 18,
            style: .continuous
        )
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
                        .foregroundColor(MimiTheme.textPrimary)
                        .frame(width: 82, alignment: .leading)
                    Text(row.1)
                        .font(.system(size: 12))
                        .foregroundColor(MimiTheme.textSecondary)
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
