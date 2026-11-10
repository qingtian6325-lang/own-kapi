import SwiftUI

public struct SettingsAndShortcutsGuideView: View {
    @ObservedObject public var store: KapiStore
    @ObservedObject public var aiEngine: KapiAIEngine
    public var initialSectionTitle: String
    public var onDismiss: () -> Void
    public var onModifyTransactionFromPopup: (TransactionItem) -> Void

    @State private var simulatedSnippetTx: TransactionItem?
    @State private var statusBannerMessage: String?

    public init(
        store: KapiStore,
        aiEngine: KapiAIEngine,
        initialSectionTitle: String = "自动记账与设置",
        onDismiss: @escaping () -> Void,
        onModifyTransactionFromPopup: @escaping (TransactionItem) -> Void
    ) {
        self.store = store
        self.aiEngine = aiEngine
        self.initialSectionTitle = initialSectionTitle
        self.onDismiss = onDismiss
        self.onModifyTransactionFromPopup = onModifyTransactionFromPopup
    }

    public var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if let banner = statusBannerMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(KapiTheme.balanceGreen)
                            Text(banner)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(KapiTheme.textPrimary)
                            Spacer()
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xE8F5E9)))
                    }

                    // 1. Live Interactive Preview of IMG_2294 Shortcut Popup
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("⚡ 自动记账 · 快捷指令截图弹窗 (IMG_2294)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(KapiTheme.textPrimary)
                            Spacer()
                        }

                        Text("在 iPhone「快捷指令」中绑定『截屏 ➔ 咔皮截图记账』，付款后敲两下手机背面即可弹出以下卡片：点击「修改 (View)」直达 App 账单详情页，点击「确认 (Got it)」直接入账。")
                            .font(.system(size: 12))
                            .foregroundColor(KapiTheme.textSecondary)

                        let previewTx = simulatedSnippetTx ?? TransactionItem(
                            type: .expense,
                            categoryPath: "餐饮-零食甜品",
                            iconName: "food_snack",
                            amount: 5.90,
                            accountName: "TNGewallet",
                            note: "Near Me Voucher Eggette Lab",
                            date: DefaultCatalog.makeDate(year: 2026, month: 11, day: 8, hour: 16, minute: 56)
                        )

                        ScreenshotResultSnippetView(
                            transaction: previewTx,
                            onModifyTapped: {
                                let draft = ReceiptOCRService.parseReceiptText(
                                    "-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34"
                                )
                                let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
                                _ = ShortcutActionCoordinator.markForInAppModification(transactionId: saved.id, in: store)
                                onModifyTransactionFromPopup(saved)
                            },
                            onConfirmTapped: {
                                let draft = ReceiptOCRService.parseReceiptText(
                                    "-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34"
                                )
                                let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
                                simulatedSnippetTx = saved
                                statusBannerMessage = "已确认记账：\(saved.categoryPath) -RM5.90 (TNGewallet)"
                            }
                        )
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))

                    // 2. AI Engine Configuration (Built-in + Optional Custom API Key)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🦫 AI 助手引擎设置")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(KapiTheme.textPrimary)

                        Text("已内置离线多笔拆单、Vision 账单 OCR 与财务官问答引擎（开箱即用，无需配置）。如需接入自定义大模型，可在下方填写：")
                            .font(.system(size: 12))
                            .foregroundColor(KapiTheme.textSecondary)

                        TextField("API Base URL (可选)", text: $aiEngine.customAPIBaseURL)
                            .font(.system(size: 13))
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))

                        SecureField("OpenAI / DeepSeek API Key (可选)", text: $aiEngine.customAPIKey)
                            .font(.system(size: 13))
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))

                    // 3. Data Management & Demo Reset
                    VStack(alignment: .leading, spacing: 12) {
                        Text("📦 数据管理与账本工具")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(KapiTheme.textPrimary)

                        Button {
                            store.resetToDemoData()
                            statusBannerMessage = "已恢复 2026年11月 默认演示账单与账户余额"
                        } label: {
                            HStack {
                                Text("恢复默认演示数据 (RM368.42 净资产)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(KapiTheme.expenseBlue)
                                Spacer()
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(KapiTheme.expenseBlue)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xE8F0FE)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.clearAllDemoTransactions()
                            statusBannerMessage = "已清空全部演示账单记录"
                        } label: {
                            HStack {
                                Text("清空全部演示账单（从零开始记账）")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(KapiTheme.dangerRed)
                                Spacer()
                                Image(systemName: "trash")
                                    .foregroundColor(KapiTheme.dangerRed)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xFFEBEE)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                }
                .padding(16)
            }
            .background(KapiTheme.background.ignoresSafeArea())
            .navigationTitle(initialSectionTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", action: onDismiss)
                }
            }
        }
    }
}
