import SwiftUI

/// 待发送的附件（小窗里先贴上，和文字一次发送）
public struct AIPendingAttachment: Identifiable, Equatable {
    public let id: UUID
    public var imageData: Data?
    public var label: String

    public init(id: UUID = UUID(), imageData: Data? = nil, label: String) {
        self.id = id
        self.imageData = imageData
        self.label = label
    }
}

/// 金标 AI 记账浮层：
/// - 小窗：贴在首页下方，可附照片 + 打字 + 三条快捷句 + 切手动；可上滑变大
/// - 发送后：全屏展开，思考中 → 回复 →「回答完毕」
public struct MimiAIAskOverlayView: View {
    @ObservedObject public var store: MimiStore
    @ObservedObject public var aiEngine: MimiAIEngine
    public var initialAttachments: [AIPendingAttachment]
    public var startExpanded: Bool
    public var onDismiss: () -> Void
    public var onOpenManual: () -> Void
    public var onOpenImportExport: () -> Void

    @State private var inputText: String = ""
    @State private var pendingAttachments: [AIPendingAttachment] = []
    @State private var isExpanded: Bool = false
    @State private var showAttachmentPanel: Bool = false
    @State private var showAlbumPicker: Bool = false
    @State private var showCameraPicker: Bool = false
    @State private var dragOffset: CGFloat = 0
    @FocusState private var inputFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if canImport(Speech) && canImport(AVFoundation)
    @StateObject private var speechTranscriber = SpeechTranscriber()
    #endif

    public init(
        store: MimiStore,
        aiEngine: MimiAIEngine,
        initialAttachments: [AIPendingAttachment] = [],
        startExpanded: Bool = false,
        onDismiss: @escaping () -> Void,
        onOpenManual: @escaping () -> Void,
        onOpenImportExport: @escaping () -> Void = {}
    ) {
        self.store = store
        self.aiEngine = aiEngine
        self.initialAttachments = initialAttachments
        self.startExpanded = startExpanded
        self.onDismiss = onDismiss
        self.onOpenManual = onOpenManual
        self.onOpenImportExport = onOpenImportExport
        _pendingAttachments = State(initialValue: initialAttachments)
        _isExpanded = State(initialValue: startExpanded)
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black.opacity(isExpanded ? 0.45 : 0.22)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if !isExpanded {
                            inputFocused = false
                            onDismiss()
                        }
                    }

                VStack(spacing: 0) {
                    // 小窗固定带三条快捷气泡；放大后不显示
                    if !isExpanded {
                        suggestionBubbles
                            .padding(.horizontal, 18)
                            .padding(.bottom, 10)
                    }

                    card(maxHeight: isExpanded ? geo.size.height * 0.92 : nil)
                        .offset(y: cardDragOffset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, isExpanded ? 0 : 10)
                .padding(.bottom, isExpanded ? 0 : 8)
            }
        }
        .onAppear {
            BookkeepingEntryPreference.rememberAI()
            // 点开一律先小窗；只有用户上滑（或发送后）才变大
            isExpanded = startExpanded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                inputFocused = true
            }
        }
        .onChange(of: aiEngine.answerJustCompleted) { _, done in
            if done {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    aiEngine.answerJustCompleted = false
                }
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showAlbumPicker) {
            PHPickerImageView { imageData in
                pendingAttachments.append(
                    AIPendingAttachment(imageData: imageData, label: "照片")
                )
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            UIKitImagePicker(sourceType: .camera) { image in
                if let data = image.jpegData(compressionQuality: 0.85) {
                    pendingAttachments.append(
                        AIPendingAttachment(imageData: data, label: "拍照")
                    )
                }
            }
        }
        #endif
    }

    // MARK: - Suggestions

    private var suggestionBubbles: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(MimiAIEngine.exampleQuestions, id: \.self) { question in
                Button {
                    inputText = question
                    sendComposed()
                } label: {
                    Text(question)
                        .mimiFont(14)
                        .foregroundColor(MimiTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(MimiTheme.cardBackground)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Card

    private func card(maxHeight: CGFloat?) -> some View {
        VStack(spacing: 0) {
            // 把手 + 顶栏：上滑放大 / 放大后下滑关闭（不跟聊天列表抢手势）
            VStack(spacing: 0) {
                Capsule()
                    .fill(MimiTheme.strokeSubtle)
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                headerRow
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(expandDragGesture)

            if !pendingAttachments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(pendingAttachmentSummary)
                        .mimiFont(12, weight: .medium)
                        .foregroundColor(MimiTheme.textSecondary)
                        .padding(.horizontal, 4)
                    pendingAttachmentStrip
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            if isExpanded {
                Divider().opacity(0.4)
                messageList
                    .frame(maxHeight: .infinity)

                if aiEngine.answerJustCompleted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(MimiTheme.balanceGreen)
                        Text("回答完毕")
                            .mimiFont(13, weight: .semibold)
                            .foregroundColor(MimiTheme.balanceGreen)
                    }
                    .padding(.vertical, 8)
                    .transition(.opacity)
                }
            }

            if showAttachmentPanel {
                AIAttachmentPanelView(
                    onPickFromAlbum: { showAlbumPicker = true },
                    onTakePhoto: { showCameraPicker = true },
                    onOpenImportExport: {
                        showAttachmentPanel = false
                        onOpenImportExport()
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            #if canImport(Speech) && canImport(AVFoundation)
            if speechTranscriber.isRecording {
                Text("正在聆听：\(speechTranscriber.partialText)")
                    .mimiFont(12)
                    .foregroundColor(MimiTheme.expenseBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
            }
            #endif

            inputRow
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, isExpanded ? 16 : 12)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: maxHeight)
        .background(
            RoundedRectangle(cornerRadius: isExpanded ? 20 : 22, style: .continuous).fill(MimiTheme.cardBackground)
                .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 6)
        )
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            MimiAskMascotView(size: 30)
            Text(isExpanded ? "来记笔账吧" : "记账查账，问问题")
                .mimiFont(16, weight: .bold)
                .foregroundColor(MimiTheme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 6)

            Button {
                BookkeepingEntryPreference.rememberManual()
                inputFocused = false
                onOpenManual()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.left.arrow.right")
                        .mimiFont(13, weight: .bold)
                    Text("手动记账")
                        .mimiFont(13, weight: .semibold)
                }
                .foregroundColor(MimiTheme.textPrimary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .frame(minHeight: MimiHIG.minTouch)
                .background(Capsule().strokeBorder(MimiTheme.strokeSubtle, lineWidth: 1))
            }
            .mimiPressable()
            .accessibilityLabel("切换到手动记账")

            Button {
                inputFocused = false
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .mimiFont(12, weight: .bold)
                    .foregroundColor(MimiTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().strokeBorder(MimiTheme.strokeSubtle, lineWidth: 1))
                    .mimiMinTouchTarget()
            }
            .mimiPressable()
            .accessibilityLabel("关闭问账")
        }
    }

    private var pendingAttachmentSummary: String {
        let labels = pendingAttachments.map(\.label)
        if labels.isEmpty { return "" }
        if labels.count == 1 { return "已选择：\(labels[0])，可继续打字后一起发送" }
        return "已选择 \(labels.count) 项：\(labels.joined(separator: "、"))，可继续打字后一起发送"
    }

    private var pendingAttachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(pendingAttachments) { item in
                    ZStack(alignment: .topTrailing) {
                        Group {
                            #if canImport(UIKit)
                            if let data = item.imageData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                attachmentPlaceholder(item.label)
                            }
                            #else
                            attachmentPlaceholder(item.label)
                            #endif
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button {
                            pendingAttachments.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .mimiFont(18)
                                .foregroundStyle(.white, Color.black.opacity(0.55))
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func attachmentPlaceholder(_ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "doc.fill")
                .mimiFont(20)
            Text(label)
                .mimiFont(10, weight: .medium)
        }
        .foregroundColor(MimiTheme.textSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MimiTheme.fillSubtle)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(aiEngine.messages) { msg in
                        bubble(msg)
                            .id(msg.id)
                    }
                    if aiEngine.isAnswering {
                        thinkingRow
                            .id("thinking")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: aiEngine.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: aiEngine.isAnswering) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var thinkingRow: some View {
        HStack(spacing: 8) {
            if reduceMotion {
                ProgressView()
                    .controlSize(.small)
                    .tint(MimiTheme.expenseBlue)
            } else {
                TimelineView(.animation(minimumInterval: 0.35, paused: false)) { context in
                    let phase = Int(context.date.timeIntervalSinceReferenceDate * 3) % 3
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(MimiTheme.expenseBlue.opacity(i == phase ? 1 : 0.35))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
            }
            Image(systemName: "sparkles")
                .foregroundColor(MimiTheme.expenseBlue)
                .accessibilityHidden(true)
            Text("咪咪思考中…")
                .mimiFont(14, weight: .medium)
                .foregroundColor(MimiTheme.expenseBlue)
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("咪咪思考中")
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                TextField(
                    isExpanded ? "任何事情都能问我" : "发消息或按住说话...",
                    text: $inputText,
                    axis: .vertical
                )
                .mimiFont(14)
                .lineLimit(1...4)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { sendComposed() }

                #if canImport(Speech) && canImport(AVFoundation)
                if inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Image(systemName: speechTranscriber.isRecording ? "mic.fill" : "mic")
                        .mimiFont(15, weight: .semibold)
                        .foregroundColor(speechTranscriber.isRecording ? MimiTheme.dangerRed : MimiTheme.textMuted)
                        .mimiMinTouchTarget(40)
                        .accessibilityLabel(speechTranscriber.isRecording ? "正在聆听，松开关闭" : "按住说话")
                        .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 60, pressing: { pressing in
                            if pressing {
                                Task {
                                    if await speechTranscriber.requestAuthorization() {
                                        speechTranscriber.startRecording()
                                    }
                                }
                            } else if speechTranscriber.isRecording {
                                let text = speechTranscriber.stopRecording()
                                if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                                    inputText = text
                                }
                            }
                        }, perform: {})
                }
                #endif

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        showAttachmentPanel.toggle()
                    }
                } label: {
                    Image(systemName: showAttachmentPanel ? "xmark" : "plus")
                        .mimiFont(15, weight: .bold)
                        .foregroundColor(MimiTheme.textMuted)
                        .mimiMinTouchTarget(40)
                }
                .mimiPressable()
                .accessibilityLabel(showAttachmentPanel ? "收起附件" : "添加照片或导入")
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(MimiTheme.background))

            Button(action: sendComposed) {
                Image(systemName: "arrow.up")
                    .mimiFont(14, weight: .bold)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(canSend ? MimiTheme.expenseBlue : Color(hex: 0xC5CCD8))
                    )
                    .mimiMinTouchTarget()
            }
            .mimiPressable()
            .disabled(!canSend)
            .accessibilityLabel("发送")
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty
    }

    // MARK: - Bubbles

    @ViewBuilder
    private func bubble(_ message: AIChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 36) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                if message.isUser, let images = aiEngine.userMessageImages[message.id], !images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(images.enumerated()), id: \.offset) { _, data in
                                #if canImport(UIKit)
                                if let ui = UIImage(data: data) {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                #endif
                            }
                        }
                    }
                }

                ForEach(Array(message.blocks.enumerated()), id: \.offset) { idx, block in
                    switch block {
                    case .pendingAnswer:
                        EmptyView()

                    case .text(let text):
                        if message.isUser {
                            Text(text)
                                .mimiFont(15)
                                .foregroundColor(MimiTheme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(MimiTheme.tintBlueSoft)
                                )
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(text)
                                    .mimiFont(15)
                                    .foregroundColor(MimiTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if idx == message.blocks.count - 1 {
                                    Text("内容由AI生成")
                                        .mimiFont(11)
                                        .foregroundColor(MimiTheme.textMuted)
                                }
                            }
                        }

                    case .draftBills(let drafts):
                        draftCard(messageId: message.id, drafts: drafts)

                    case .categoryTable(let expenseRows, let incomeRows, let customNote):
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(expenseRows.enumerated()), id: \.offset) { _, row in
                                Text("\(row.0)：\(row.1)")
                                    .mimiFont(13)
                                    .foregroundColor(MimiTheme.textSecondary)
                            }
                            if !customNote.isEmpty {
                                Text(customNote)
                                    .mimiFont(12)
                                    .foregroundColor(MimiTheme.textMuted)
                            }
                            if !incomeRows.isEmpty {
                                Text("收入分类已包含在上方说明里")
                                    .mimiFont(12)
                                    .foregroundColor(MimiTheme.textMuted)
                            }
                        }

                    case .spendingSummary(let title, let amount, let count, let details):
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title).mimiFont(15, weight: .bold)
                            Text("总支出 \(MimiTheme.formatRM(amount)) · 共 \(count) 笔")
                                .mimiFont(14, weight: .semibold)
                                .foregroundColor(MimiTheme.expenseBlue)
                            Text(details)
                                .mimiFont(13)
                                .foregroundColor(MimiTheme.textSecondary)
                        }
                    }
                }
            }

            if !message.isUser { Spacer(minLength: 24) }
        }
    }

    private func draftCard(messageId: UUID, drafts: [ParsedDraftBill]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(drafts) { draft in
                HStack(spacing: 10) {
                    MimiStickerIconView(
                        iconName: draft.iconName,
                        categoryName: draft.categoryPath,
                        transactionType: draft.type,
                        size: 36
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(draft.categoryPath)
                            .mimiFont(14, weight: .semibold)
                        Text("\(draft.accountName) · \(draft.note)")
                            .mimiFont(12)
                            .foregroundColor(MimiTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text((draft.type == .income ? "+" : "-") + MimiTheme.formatRM(draft.amount))
                        .mimiFont(14, weight: .bold, design: .rounded)
                        .foregroundColor(draft.type == .income ? MimiTheme.incomeOrange : MimiTheme.expenseBlue)
                }
            }
            HStack(spacing: 10) {
                Button { aiEngine.cancelDrafts(messageId: messageId) } label: {
                    Text("取消")
                        .mimiFont(13, weight: .semibold)
                        .foregroundColor(MimiTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(MimiTheme.fillSubtle))
                }
                .buttonStyle(.plain)
                Button { aiEngine.confirmDrafts(messageId: messageId, in: store) } label: {
                    Text("确认记账")
                        .mimiFont(13, weight: .semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(MimiTheme.expenseBlue))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MimiTheme.fillSubtle))
    }

    // MARK: - Gestures / Actions

    private var cardDragOffset: CGFloat {
        if isExpanded {
            return max(0, dragOffset)
        }
        return min(0, dragOffset)
    }

    private var expandDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if isExpanded {
                    // 放大后只能往下拖，准备关掉
                    dragOffset = max(0, value.translation.height)
                } else if value.translation.height < -24 {
                    // 小窗往上拖，准备变大
                    dragOffset = value.translation.height
                } else {
                    dragOffset = 0
                }
            }
            .onEnded { value in
                if !isExpanded && value.translation.height < -80 {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        isExpanded = true
                    }
                    dragOffset = 0
                } else if isExpanded && value.translation.height > 120 {
                    // 放大后往下划 → 直接关掉，不退回小窗
                    dragOffset = 0
                    inputFocused = false
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func sendComposed() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = pendingAttachments.compactMap(\.imageData)
        guard !text.isEmpty || !images.isEmpty else { return }

        inputText = ""
        pendingAttachments = []
        showAttachmentPanel = false
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            isExpanded = true
        }
        aiEngine.sendComposed(text: text, imageDataList: images, store: store)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                if aiEngine.isAnswering {
                    proxy.scrollTo("thinking", anchor: .bottom)
                } else if let last = aiEngine.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}
