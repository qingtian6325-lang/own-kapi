import SwiftUI

public struct KapiRootContainerView: View {
    @ObservedObject public var store: KapiStore
    @StateObject private var aiEngine = KapiAIEngine()

    @State private var currentMainPage: String = "记录" // "记录" or "Kapi"
    @State private var isDrawerOpen: Bool = false
    @State private var showAllRecordsCalendar: Bool = false
    @State private var showRecordSheet: Bool = false
    @State private var openRecordSheetInAIMode: Bool = false
    @State private var activeBillForEdit: TransactionItem?
    @State private var showAssetsManager: Bool = false
    @State private var showBudgetManager: Bool = false
    @State private var showCategoryManager: Bool = false
    @State private var activeSettingsTitle: String?

    public init(store: KapiStore = .shared) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .top) {
            if currentMainPage == "Kapi" {
                KapiStatsView(
                    store: store,
                    onOpenDrawer: {
                        withAnimation(.easeOut(duration: 0.22)) {
                            isDrawerOpen = true
                        }
                    },
                    onSwitchToHome: {
                        currentMainPage = "记录"
                    },
                    onOpenAssets: {
                        showAssetsManager = true
                    }
                )
            } else {
                HomeRecordView(
                    store: store,
                    onOpenDrawer: {
                        withAnimation(.easeOut(duration: 0.22)) {
                            isDrawerOpen = true
                        }
                    },
                    onSwitchToStats: {
                        currentMainPage = "Kapi"
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
                    }
                )
            }

            // Top floating Shortcut Snippet Overlay when triggered via URL / Quick-Scan
            if let snippetBill = store.pendingShortcutSnippetBill {
                ScreenshotResultSnippetView(
                    transaction: snippetBill,
                    onModifyTapped: {
                        store.pendingShortcutSnippetBill = nil
                        activeBillForEdit = snippetBill
                    },
                    onConfirmTapped: {
                        store.pendingShortcutSnippetBill = nil
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(20)
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
                        isDrawerOpen = false
                        handleDrawerSelection(dest)
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
        .onChange(of: store.pendingEditTransactionId) { _, newId in
            if let id = newId,
               let match = store.transactions.first(where: { $0.id == id }) {
                activeBillForEdit = match
            }
        }
        .onOpenURL { url in
            if ShortcutActionCoordinator.handleIncomingURL(url, in: store),
               let id = store.pendingEditTransactionId,
               let match = store.transactions.first(where: { $0.id == id }) {
                activeBillForEdit = match
            }
        }
    }

    private func handleDrawerSelection(_ destination: DrawerDestination) {
        switch destination {
        case .stats:
            currentMainPage = "Kapi"
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
