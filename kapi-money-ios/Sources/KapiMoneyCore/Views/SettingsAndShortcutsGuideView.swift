import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

public struct SettingsAndShortcutsGuideView: View {
    @ObservedObject public var store: KapiStore
    @ObservedObject public var aiEngine: KapiAIEngine
    public var initialSectionTitle: String
    public var onDismiss: () -> Void
    public var onModifyTransactionFromPopup: (TransactionItem) -> Void

    @State private var simulatedSnippetTx: TransactionItem?
    @State private var statusBannerMessage: String?
    @State private var showFileImporter: Bool = false
    @State private var showPasteSheet: Bool = false
    @State private var pastedCSVText: String = ""
    @State private var replaceExistingOnImport: Bool = false
    @State private var showResetCleanAlert: Bool = false

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

                    // If user tapped "导入导出" in the drawer, show CSV card first
                    if initialSectionTitle == "导入导出" {
                        csvImportExportCard
                        shortcutsCard
                        aiEngineCard
                        dataManagementCard
                    } else {
                        shortcutsCard
                        csvImportExportCard
                        aiEngineCard
                        dataManagementCard
                    }
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
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showPasteSheet) {
                pasteCSVSheet
            }
            .alert("确认清空全部账单？", isPresented: $showResetCleanAlert) {
                Button("取消", role: .cancel) {}
                Button("清空并重置为全新空白", role: .destructive) {
                    store.resetToCleanEmpty()
                    statusBannerMessage = "已彻底清空全部账单与账户余额（全新初始状态）"
                }
            } message: {
                Text("此操作会将账单、账户余额与审计日志全部重置为 RM0.00。")
            }
        }
    }

    // MARK: - CSV Import & Export Card

    private var csvImportExportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📥 导入导出 · 咔皮双表 CSV 账单")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)
                Spacer()
            }

            Text("完美支持咔皮记账导出的双表 CSV 结构（包括上表13个字段的收支明细与下表7个字段的账户互转，自动处理多行带引号备注）。")
                .font(.system(size: 12))
                .foregroundColor(KapiTheme.textSecondary)

            Toggle(isOn: $replaceExistingOnImport) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("导入时清空覆盖现有账单")
                        .font(.system(size: 13, weight: .medium))
                    Text("开启后将从零载入新 CSV，关闭则累加追加至现有账单")
                        .font(.system(size: 11))
                        .foregroundColor(KapiTheme.textMuted)
                }
            }
            .padding(.vertical, 4)

            Divider()

            // Button 1: From Files App
            Button {
                showFileImporter = true
            } label: {
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                        .foregroundColor(KapiTheme.expenseBlue)
                    Text("从「文件」App 选择 CSV 文件导入")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(KapiTheme.expenseBlue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(KapiTheme.expenseBlue)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xE8F0FE)))
            }
            .buttonStyle(.plain)

            // Button 2: Paste CSV Text
            Button {
                showPasteSheet = true
            } label: {
                HStack {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(KapiTheme.expenseBlue)
                    Text("粘贴 CSV 文本快速导入")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(KapiTheme.expenseBlue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(KapiTheme.expenseBlue)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xE8F0FE)))
            }
            .buttonStyle(.plain)

            // Button 3: Convenience one-click import user exported 151 records
            Button {
                let count = store.importKapiCSV(KapiCSVService.userExportedCSV, replaceExisting: replaceExistingOnImport)
                statusBannerMessage = "已成功导入 \(count) 笔咔皮账单（含 140 笔收支 + 11 笔账户互转）"
            } label: {
                HStack {
                    Image(systemName: "arrow.down.doc.fill")
                        .foregroundColor(Color(hex: 0x2E7D32))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("一键导入我的 151 笔账单备份")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: 0x2E7D32))
                        Text("包含 2026.09 - 2026.11 真实导出的 140 笔收支及 11 笔互转")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: 0x2E7D32).opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0x2E7D32))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xE8F5E9)))
            }
            .buttonStyle(.plain)

            // Button 4: Export CSV via ShareLink
            ShareLink(
                item: store.exportKapiCSV(),
                preview: SharePreview("KapiMoney_Export.csv", image: Image(systemName: "tablecells"))
            ) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(KapiTheme.textPrimary)
                    Text("导出当前全部账单为 CSV 文件")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(KapiTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(KapiTheme.textSecondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF5F6FA)))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    private var pasteCSVSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("在此处粘贴咔皮记账的 CSV 文本内容：")
                    .font(.system(size: 13))
                    .foregroundColor(KapiTheme.textSecondary)

                TextEditor(text: $pastedCSVText)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(KapiTheme.divider, lineWidth: 1))

                Button {
                    let count = store.importKapiCSV(pastedCSVText, replaceExisting: replaceExistingOnImport)
                    showPasteSheet = false
                    pastedCSVText = ""
                    statusBannerMessage = "已通过文本导入 \(count) 笔账单记录"
                } label: {
                    Text("确认解析并导入")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(KapiTheme.expenseBlue))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .navigationTitle("粘贴 CSV 导入")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showPasteSheet = false }
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let selectedUrl = try result.get().first else { return }
            let canAccess = selectedUrl.startAccessingSecurityScopedResource()
            defer {
                if canAccess { selectedUrl.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: selectedUrl)
            guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
                statusBannerMessage = "CSV 文件编码未能识别为 UTF-8"
                return
            }
            let count = store.importKapiCSV(content, replaceExisting: replaceExistingOnImport)
            statusBannerMessage = "已从文件导入 \(count) 笔账单记录"
        } catch {
            statusBannerMessage = "读取 CSV 文件失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Shortcuts Popup Card

    private var shortcutsCard: some View {
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

            VStack(alignment: .leading, spacing: 6) {
                Text("📌 3 步设置「背面轻点两下」无感记账：")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)
                Text("1. 打开 iPhone「设置」➔「辅助功能」➔「触控」➔「轻点背面」")
                    .font(.system(size: 12))
                    .foregroundColor(KapiTheme.textSecondary)
                Text("2. 点击「轻点两下」，往下滑动到快捷指令列表")
                    .font(.system(size: 12))
                    .foregroundColor(KapiTheme.textSecondary)
                Text("3. 勾选「咔皮截图记账」（App 已原生内置提供，开箱即选）")
                    .font(.system(size: 12))
                    .foregroundColor(KapiTheme.textSecondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF5F6FA)))

            HStack(spacing: 10) {
                Link(destination: URL(string: "shortcuts://")!) {
                    HStack {
                        Image(systemName: "arrow.up.forward.app")
                        Text("打开「快捷指令」App")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(KapiTheme.expenseBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(hex: 0xE8F0FE)))
                }

                Button {
                    let demoDraft = ReceiptOCRService.parseReceiptText(
                        "-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34"
                    )
                    let saved = ShortcutActionCoordinator.recordRecognizedDraft(demoDraft, in: store)
                    simulatedSnippetTx = saved
                    statusBannerMessage = "已模拟触发快捷指令截图识别"
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("模拟触发弹窗")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(KapiTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(hex: 0xF0F2F7)))
                }
                .buttonStyle(.plain)
            }

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
    }

    // MARK: - AI Engine Settings Card

    private var aiEngineCard: some View {
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
    }

    // MARK: - Data Management Card

    private var dataManagementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📦 数据管理与账本工具")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(KapiTheme.textPrimary)

            Button {
                showResetCleanAlert = true
            } label: {
                HStack {
                    Text("清空全部账单与余额（恢复空白初始状态）")
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

            Button {
                store.resetToDemoData()
                statusBannerMessage = "已恢复 2026年11月 官方演示账单与账户余额 (RM368.42)"
            } label: {
                HStack {
                    Text("恢复官方演示数据 (用于功能测试)")
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
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }
}
