import SwiftUI

public struct MimiRootContainerView: View {
    @ObservedObject public var store: MimiStore
    @StateObject private var aiEngine = MimiAIEngine()

    @State private var currentMainPage: String = "记录"
    @State private var isDrawerOpen: Bool = false
    @State private var showStatsView: Bool = false
    @State private var showAllRecordsCalendar: Bool = false
    @State private var showRecordSheet: Bool = false
    @State private var openRecordSheetInAIMode: Bool = false
    /// 金标 AI 记账：首页浮层（不是整页 sheet）
    @State private var showAIAskOverlay: Bool = false
    @State private var aiOverlayAttachments: [AIPendingAttachment] = []
    @State private var activeBillForEdit: TransactionItem?
    @State private var showAssetsManager: Bool = false
    @State private var showBudgetManager: Bool = false
    @State private var showCategoryManager: Bool = false
    @State private var activeSettingsTitle: String?
    @State private var showHomeAlbumPicker: Bool = false
    @State private var showHomeCameraPicker: Bool = false
    @State private var homeRecognizedDraft: ParsedDraftBill?
    @State private var homeRecognitionFailureText: String?

    @MainActor
    public init(store: MimiStore = .shared) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .top) {
            HomeRecordView(
                store: store,
                onOpenDrawer: {
                    withAnimation(.easeOut(duration: 0.22)) {
                        isDrawerOpen = true
                    }
                },
                onSwitchToStats: {
                    pushOpen { showStatsView = true }
                },
                onOpenSearchOrCalendar: {
                    pushOpen { showAllRecordsCalendar = true }
                },
                onOpenRecordSheet: { aiMode in
                    if aiMode {
                        aiOverlayAttachments = []
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            showAIAskOverlay = true
                        }
                    } else {
                        BookkeepingEntryPreference.rememberManual()
                        openRecordSheetInAIMode = false
                        showRecordSheet = true
                    }
                },
                onSelectTransaction: { tx in
                    pushOpen { activeBillForEdit = tx }
                },
                onOpenBudgetManager: {
                    pushOpen { showBudgetManager = true }
                },
                onOpenAssetsManager: {
                    pushOpen { showAssetsManager = true }
                },
                onPickFromAlbum: {
                    showHomeAlbumPicker = true
                },
                onTakePhoto: {
                    showHomeCameraPicker = true
                },
                onOpenImportExport: {
                    pushOpen { activeSettingsTitle = DrawerDestination.importExport.rawValue }
                }
            )

            // Top floating Shortcut Snippet Overlay when triggered via URL / Quick-Scan
            if let snippetBill = store.pendingShortcutSnippetBill {
                ZStack(alignment: .top) {
                    // Tap anywhere outside to dismiss
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                store.pendingShortcutSnippetBill = nil
                            }
                        }

                    ScreenshotResultSnippetView(
                        transaction: snippetBill,
                        onModifyTapped: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                store.pendingShortcutSnippetBill = nil
                            }
                            pushOpen { activeBillForEdit = snippetBill }
                        },
                        onConfirmTapped: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                store.pendingShortcutSnippetBill = nil
                            }
                        },
                        onCloseTapped: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                store.pendingShortcutSnippetBill = nil
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                if value.translation.height < -15 {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        store.pendingShortcutSnippetBill = nil
                                    }
                                }
                            }
                    )
                }
                .transition(.opacity)
                .zIndex(20)
                .onAppear {
                    // Auto-dismiss after 5 seconds so it never blocks the user screen indefinitely
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        if store.pendingShortcutSnippetBill?.id == snippetBill.id {
                            withAnimation(.easeOut(duration: 0.25)) {
                                store.pendingShortcutSnippetBill = nil
                            }
                        }
                    }
                }
            }

            // 问账条面板（相册/拍照）识别出的账单草稿：App 内确认后才入账
            if let homeDraft = homeRecognizedDraft {
                ZStack(alignment: .top) {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .onTapGesture {
                            homeRecognizedDraft = nil
                        }

                    ScreenshotResultSnippetView(
                        transaction: TransactionItem(
                            type: homeDraft.type,
                            categoryPath: homeDraft.categoryPath,
                            iconName: homeDraft.iconName,
                            amount: homeDraft.amount,
                            accountName: homeDraft.accountName,
                            targetAccountName: homeDraft.targetAccountName,
                            note: homeDraft.note,
                            date: homeDraft.date
                        ),
                        onModifyTapped: {
                            let saved = ShortcutActionCoordinator.recordRecognizedDraft(homeDraft, in: store)
                            homeRecognizedDraft = nil
                            pushOpen { activeBillForEdit = saved }
                        },
                        onConfirmTapped: {
                            _ = ShortcutActionCoordinator.recordRecognizedDraft(homeDraft, in: store)
                            homeRecognizedDraft = nil
                        },
                        onCloseTapped: {
                            homeRecognizedDraft = nil
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .transition(.opacity)
                .zIndex(25)
            }

            if showAIAskOverlay {
                MimiAIAskOverlayView(
                    store: store,
                    aiEngine: aiEngine,
                    initialAttachments: aiOverlayAttachments,
                    startExpanded: false,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.22)) {
                            showAIAskOverlay = false
                            aiOverlayAttachments = []
                        }
                    },
                    onOpenManual: {
                        BookkeepingEntryPreference.rememberManual()
                        withAnimation(.easeOut(duration: 0.18)) {
                            showAIAskOverlay = false
                            aiOverlayAttachments = []
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            openRecordSheetInAIMode = false
                            showRecordSheet = true
                        }
                    },
                    onOpenImportExport: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showAIAskOverlay = false
                            aiOverlayAttachments = []
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            pushOpen { activeSettingsTitle = DrawerDestination.importExport.rawValue }
                        }
                    }
                )
                .id(aiOverlayAttachments.map(\.id.uuidString).joined(separator: "-"))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(55)
            }

            if isDrawerOpen {
                SideDrawerMenuView(
                    store: store,
                    onClose: {
                        withAnimation(.easeIn(duration: 0.2)) {
                            isDrawerOpen = false
                        }
                    },
                    onSelectDestination: { dest in
                        withAnimation(.easeIn(duration: 0.2)) {
                            isDrawerOpen = false
                        }
                        // 等抽屉先收完再从右侧推进页面
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                            handleDrawerSelection(dest)
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(30)
            }

            // 功能页：打开从右往左推进，返回从左往右退出
            if showStatsView {
                MimiStatsView(
                    store: store,
                    onOpenDrawer: {
                        pushClose { showStatsView = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                            withAnimation(.easeOut(duration: 0.22)) {
                                isDrawerOpen = true
                            }
                        }
                    },
                    onSwitchToHome: {
                        pushClose { showStatsView = false }
                    },
                    onOpenAssets: {
                        pushClose { showStatsView = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                            pushOpen { showAssetsManager = true }
                        }
                    }
                )
                .transition(Self.pagePushTransition)
                .zIndex(40)
            }

            if showAllRecordsCalendar {
                AllRecordsCalendarView(
                    store: store,
                    onDismiss: { pushClose { showAllRecordsCalendar = false } },
                    onSelectTransaction: { tx in
                        pushClose { showAllRecordsCalendar = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                            pushOpen { activeBillForEdit = tx }
                        }
                    }
                )
                .transition(Self.pagePushTransition)
                .zIndex(41)
            }

            if showAssetsManager {
                AssetsAndAccountDetailView(
                    store: store,
                    onDismiss: { pushClose { showAssetsManager = false } }
                )
                .transition(Self.pagePushTransition)
                .zIndex(42)
            }

            if showBudgetManager {
                BudgetManagementView(
                    store: store,
                    onDismiss: { pushClose { showBudgetManager = false } }
                )
                .transition(Self.pagePushTransition)
                .zIndex(43)
            }

            if showCategoryManager {
                CategoryManagementView(
                    store: store,
                    onDismiss: { pushClose { showCategoryManager = false } }
                )
                .transition(Self.pagePushTransition)
                .zIndex(44)
            }

            if let settingsTitle = activeSettingsTitle {
                SettingsAndShortcutsGuideView(
                    store: store,
                    aiEngine: aiEngine,
                    initialSectionTitle: settingsTitle,
                    onDismiss: { pushClose { activeSettingsTitle = nil } },
                    onModifyTransactionFromPopup: { tx in
                        pushClose { activeSettingsTitle = nil }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                            pushOpen { activeBillForEdit = tx }
                        }
                    }
                )
                .transition(Self.pagePushTransition)
                .zIndex(45)
            }

            if let bill = activeBillForEdit {
                BillDetailSheetView(
                    store: store,
                    transaction: bill,
                    onDismiss: {
                        pushClose {
                            activeBillForEdit = nil
                            store.pendingEditTransactionId = nil
                        }
                    }
                )
                .transition(Self.pagePushTransition)
                .zIndex(50)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: showAIAskOverlay)
        .animation(Self.pagePushAnimation, value: showStatsView)
        .animation(Self.pagePushAnimation, value: showAllRecordsCalendar)
        .animation(Self.pagePushAnimation, value: showAssetsManager)
        .animation(Self.pagePushAnimation, value: showBudgetManager)
        .animation(Self.pagePushAnimation, value: showCategoryManager)
        .animation(Self.pagePushAnimation, value: activeSettingsTitle)
        .animation(Self.pagePushAnimation, value: activeBillForEdit?.id)
        .sheet(isPresented: $showRecordSheet) {
            RecordAndAISheetView(
                store: store,
                aiEngine: aiEngine,
                initialAIMode: openRecordSheetInAIMode,
                onDismiss: { showRecordSheet = false },
                onOpenCategorySettings: {
                    showRecordSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        pushOpen { showCategoryManager = true }
                    }
                },
                onEditRecognizedTransaction: { savedTx in
                    showRecordSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        pushOpen { activeBillForEdit = savedTx }
                    }
                },
                onOpenImportExport: {
                    showRecordSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        pushOpen { activeSettingsTitle = DrawerDestination.importExport.rawValue }
                    }
                },
                onSwitchToAIOverlay: {
                    BookkeepingEntryPreference.rememberAI()
                    showRecordSheet = false
                    aiOverlayAttachments = []
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            showAIAskOverlay = true
                        }
                    }
                }
            )
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showHomeAlbumPicker) {
            PHPickerImageView { imageData in
                recognizeHomeImage(imageData)
            }
        }
        .sheet(isPresented: $showHomeCameraPicker) {
            UIKitImagePicker(sourceType: .camera) { image in
                if let data = image.jpegData(compressionQuality: 0.85) {
                    recognizeHomeImage(data)
                }
            }
        }
        #endif
        .onChange(of: store.pendingEditTransactionId) { _, newId in
            if let id = newId,
               let match = store.transactions.first(where: { $0.id == id }) {
                pushOpen { activeBillForEdit = match }
            }
        }
        .onChange(of: store.isRecordSheetPresented) { _, presented in
            if presented {
                openRecordSheetInAIMode = false
                showRecordSheet = true
                store.isRecordSheetPresented = false
            }
        }
        .onOpenURL { url in
            if ShortcutActionCoordinator.handleIncomingURL(url, in: store),
               let id = store.pendingEditTransactionId,
               let match = store.transactions.first(where: { $0.id == id }) {
                pushOpen { activeBillForEdit = match }
            }
        }
        .alert("AI 识别失败", isPresented: Binding(
            get: { homeRecognitionFailureText != nil },
            set: { if !$0 { homeRecognitionFailureText = nil } }
        )) {
            Button("好") { homeRecognitionFailureText = nil }
        } message: {
            Text(homeRecognitionFailureText ?? "")
        }
    }

    /// 打开：从右往左；关闭：从左往右（同一 trailing edge）
    private static var pagePushTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    private static var pagePushAnimation: Animation {
        .easeInOut(duration: 0.32)
    }

    private func pushOpen(_ updates: @escaping () -> Void) {
        withAnimation(Self.pagePushAnimation, updates)
    }

    private func pushClose(_ updates: @escaping () -> Void) {
        withAnimation(Self.pagePushAnimation, updates)
    }

    /// 首页 ＋ 面板选图/拍照：先进入 AI 小窗，带上照片，用户可再打字后一次发送。
    private func openAIComposer(withImageData imageData: Data, label: String) {
        BookkeepingEntryPreference.rememberAI()
        aiOverlayAttachments = [AIPendingAttachment(imageData: imageData, label: label)]
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            showAIAskOverlay = true
        }
    }

    private func recognizeHomeImage(_ imageData: Data) {
        openAIComposer(withImageData: imageData, label: "照片")
    }

    private func handleDrawerSelection(_ destination: DrawerDestination) {
        pushOpen {
            switch destination {
            case .calendar:
                showAllRecordsCalendar = true
            case .stats:
                showStatsView = true
            case .assets:
                showAssetsManager = true
            case .budgets:
                showBudgetManager = true
            case .categories:
                showCategoryManager = true
            case .ledgers, .widgets, .tags, .importExport, .autoBookkeeping, .scheduledBookkeeping, .settings:
                activeSettingsTitle = destination.rawValue
            }
        }
    }
}
