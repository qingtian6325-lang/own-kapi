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
                    showStatsView = true
                },
                onOpenSearchOrCalendar: {
                    showAllRecordsCalendar = true
                },
                onOpenRecordSheet: { aiMode in
                    openRecordSheetInAIMode = aiMode
                    showRecordSheet = true
                },
                onSelectTransaction: { tx in
                    activeBillForEdit = tx
                },
                onOpenBudgetManager: {
                    showBudgetManager = true
                },
                onOpenAssetsManager: {
                    showAssetsManager = true
                },
                onPickFromAlbum: {
                    showHomeAlbumPicker = true
                },
                onTakePhoto: {
                    showHomeCameraPicker = true
                },
                onOpenImportExport: {
                    activeSettingsTitle = DrawerDestination.importExport.rawValue
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
                            activeBillForEdit = snippetBill
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
                            activeBillForEdit = saved
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
                        // 等抽屉先收完再出 sheet，避免「点了资产管理像卡住、详情不出来」
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                            handleDrawerSelection(dest)
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(30)
            }
        }
        .sheet(isPresented: $showRecordSheet) {
            RecordAndAISheetView(
                store: store,
                aiEngine: aiEngine,
                initialAIMode: openRecordSheetInAIMode,
                onDismiss: { showRecordSheet = false },
                onOpenCategorySettings: {
                    showRecordSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showCategoryManager = true
                    }
                },
                onEditRecognizedTransaction: { savedTx in
                    showRecordSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        activeBillForEdit = savedTx
                    }
                },
                onOpenImportExport: {
                    showRecordSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        activeSettingsTitle = DrawerDestination.importExport.rawValue
                    }
                }
            )
        }
        .sheet(item: $activeBillForEdit) { bill in
            BillDetailSheetView(
                store: store,
                transaction: bill,
                onDismiss: {
                    activeBillForEdit = nil
                    store.pendingEditTransactionId = nil
                }
            )
        }
        .sheet(isPresented: $showStatsView) {
            MimiStatsView(
                store: store,
                onOpenDrawer: {
                    showStatsView = false
                    withAnimation(.easeOut(duration: 0.22)) {
                        isDrawerOpen = true
                    }
                },
                onSwitchToHome: {
                    showStatsView = false
                },
                onOpenAssets: {
                    showStatsView = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showAssetsManager = true
                    }
                }
            )
        }
        .sheet(isPresented: $showAllRecordsCalendar) {
            AllRecordsCalendarView(
                store: store,
                onDismiss: { showAllRecordsCalendar = false },
                onSelectTransaction: { tx in
                    showAllRecordsCalendar = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        activeBillForEdit = tx
                    }
                }
            )
        }
        .sheet(isPresented: $showAssetsManager) {
            AssetsAndAccountDetailView(
                store: store,
                onDismiss: { showAssetsManager = false }
            )
        }
        .sheet(isPresented: $showBudgetManager) {
            BudgetManagementView(
                store: store,
                onDismiss: { showBudgetManager = false }
            )
        }
        .sheet(isPresented: $showCategoryManager) {
            CategoryManagementView(
                store: store,
                onDismiss: { showCategoryManager = false }
            )
        }
        .sheet(
            isPresented: Binding(
                get: { activeSettingsTitle != nil },
                set: { if !$0 { activeSettingsTitle = nil } }
            )
        ) {
            SettingsAndShortcutsGuideView(
                store: store,
                aiEngine: aiEngine,
                initialSectionTitle: activeSettingsTitle ?? "自动记账",
                onDismiss: { activeSettingsTitle = nil },
                onModifyTransactionFromPopup: { tx in
                    activeSettingsTitle = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        activeBillForEdit = tx
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
                activeBillForEdit = match
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
                activeBillForEdit = match
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

    /// 首页问账条面板选图/拍照后的识别：纯 AI（Gemini），成功才出草稿卡等待确认；
    /// 可疑金额直接以未确认状态入账并打开编辑页（与 Intent 路径一致）；
    /// 失败弹窗如实说明原因，不生成草稿、不落账。
    private func recognizeHomeImage(_ imageData: Data) {
        Task {
            do {
                let result = try await SmartReceiptRecognizer.recognize(imageData: imageData)
                await MainActor.run {
                    if result.isSuspiciousAmount {
                        let tx = ShortcutActionCoordinator.makeTransaction(
                            from: result.draft,
                            in: store,
                            isConfirmed: false
                        )
                        store.addTransaction(tx)
                        _ = ShortcutActionCoordinator.markForInAppModification(transactionId: tx.id, in: store)
                        activeBillForEdit = tx
                        homeRecognizedDraft = nil
                    } else {
                        homeRecognizedDraft = result.draft
                    }
                }
            } catch {
                let text = (error as? ReceiptRecognitionFailure)?.dialogText
                    ?? ReceiptRecognitionFailure.failed(reason: error.localizedDescription).dialogText
                await MainActor.run {
                    homeRecognitionFailureText = text
                }
            }
        }
    }

    private func handleDrawerSelection(_ destination: DrawerDestination) {
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
