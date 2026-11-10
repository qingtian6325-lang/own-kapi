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

    // Ledger management states
    @State private var newLedgerName: String = ""
    @State private var newLedgerCurrency: CurrencyCode = .myr
    @State private var newLedgerBudget: String = "3000"
    @State private var showCreateLedgerSheet: Bool = false
    @State private var editingLedgerForBudget: LedgerItem?
    @State private var editBudgetInput: String = ""

    // Tag management states
    @State private var newTagName: String = ""
    @State private var selectedFilterTag: String? = nil

    // Scheduled bookkeeping states
    @State private var showCreateScheduledSheet: Bool = false
    @State private var newScheduledTitle: String = ""
    @State private var newScheduledType: TransactionType = .expense
    @State private var newScheduledAmount: String = ""
    @State private var newScheduledAccount: String = "PBBank"
    @State private var newScheduledFreq: RecurringFrequency = .monthly
    @State private var newScheduledDay: Int = 1

    // General settings
    @State private var editingNickname: String = ""

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

                    switch initialSectionTitle {
                    case "账本管理":
                        ledgerManagementSection
                    case "标签管理":
                        tagManagementSection
                    case "定时记账":
                        scheduledBookkeepingSection
                    case "小组件":
                        widgetsShowcaseSection
                    case "设置":
                        generalSettingsSection
                    case "导入导出":
                        csvImportExportCard
                        dataManagementCard
                    default: // 自动记账
                        shortcutsCard
                        aiEngineCard
                        csvImportExportCard
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

    // MARK: - 1. 账本管理 (Ledger Management Section)

    private var ledgerManagementSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("📒 全部账本 (\(store.ledgers.count))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)
                Spacer()
                Button {
                    showCreateLedgerSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("新建账本")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(KapiTheme.expenseBlue)
                }
            }

            ForEach(store.ledgers) { ledger in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("📒")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(ledger.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(KapiTheme.textPrimary)
                                if ledger.id == store.currentLedgerId {
                                    Text("当前使用")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(KapiTheme.balanceGreen)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color(hex: 0xE8F5E9)))
                                }
                            }
                            Text("主币种: \(ledger.currency.rawValue) · 月预算: \(KapiTheme.formatRM(ledger.monthlyBudget))")
                                .font(.system(size: 11))
                                .foregroundColor(KapiTheme.textSecondary)
                        }
                        Spacer()

                        if ledger.id != store.currentLedgerId {
                            Button("切换") {
                                store.switchLedger(id: ledger.id)
                                statusBannerMessage = "已切换到账本: \(ledger.name)"
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(KapiTheme.expenseBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color(hex: 0xE8F0FE)))
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            editingLedgerForBudget = ledger
                            editBudgetInput = String(format: "%.0f", ledger.monthlyBudget)
                        } label: {
                            Text("修改月预算")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(KapiTheme.expenseBlue)
                        }

                        Spacer()

                        if store.ledgers.count > 1 {
                            Button {
                                store.deleteLedger(id: ledger.id)
                                statusBannerMessage = "已删除账本: \(ledger.name)"
                            } label: {
                                Text("删除")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(KapiTheme.dangerRed)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            }
        }
        .sheet(item: $editingLedgerForBudget) { ledger in
            NavigationStack {
                VStack(spacing: 16) {
                    Text("调整「\(ledger.name)」的每月预算金额")
                        .font(.system(size: 13))
                        .foregroundColor(KapiTheme.textSecondary)
                        .padding(.top, 16)
                    TextField("输入预算金额", text: $editBudgetInput)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF5F6FA)))
                        .padding(.horizontal, 32)
                    Button {
                        if let val = Double(editBudgetInput), val >= 0 {
                            store.updateLedgerBudget(id: ledger.id, newBudget: val)
                            statusBannerMessage = "已更新账本预算为 \(KapiTheme.formatRM(val))"
                        }
                        editingLedgerForBudget = nil
                    } label: {
                        Text("保存预算")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(KapiTheme.expenseBlue))
                    }
                    .padding(.horizontal, 32)
                    Spacer()
                }
                .navigationTitle("修改月预算")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { editingLedgerForBudget = nil }
                    }
                }
            }
            .presentationDetents([.height(260)])
        }
        .sheet(isPresented: $showCreateLedgerSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Text("账本名称")
                        .font(.system(size: 13, weight: .semibold))
                    TextField("如：生意账本 / 旅行账本 / 装修账本", text: $newLedgerName)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))

                    Text("每月预算 (RM)")
                        .font(.system(size: 13, weight: .semibold))
                    TextField("3000", text: $newLedgerBudget)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))

                    Button {
                        let trimmed = newLedgerName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let budget = Double(newLedgerBudget) ?? 3000.0
                        store.addLedger(name: trimmed, currency: newLedgerCurrency, monthlyBudget: budget)
                        newLedgerName = ""
                        showCreateLedgerSheet = false
                        statusBannerMessage = "已创建并切换到新账本: \(trimmed)"
                    } label: {
                        Text("确认创建账本")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(KapiTheme.expenseBlue))
                    }
                    .padding(.top, 10)

                    Spacer()
                }
                .padding(16)
                .navigationTitle("新建账本")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showCreateLedgerSheet = false }
                    }
                }
            }
            .presentationDetents([.height(320)])
        }
    }

    // MARK: - 2. 标签管理 (Tag Management Section)

    private var tagManagementSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("🏷️ 标签管理 (\(store.tags.count))")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(KapiTheme.textPrimary)

            Text("为账单打上标签（如：报销、旅行、人情），可以在此统一统计与筛选。")
                .font(.system(size: 12))
                .foregroundColor(KapiTheme.textSecondary)

            // Add tag input
            HStack(spacing: 8) {
                TextField("输入新标签名称 (如：兼职/自驾游)", text: $newTagName)
                    .font(.system(size: 13))
                    .padding(9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                Button("添加") {
                    let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    store.addTag(trimmed)
                    newTagName = ""
                    statusBannerMessage = "已添加新标签: #\(trimmed)"
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(KapiTheme.expenseBlue))
            }

            // Tag chips
            VStack(alignment: .leading, spacing: 10) {
                Text("现有标签列表（点击标签可筛选关联账单）：")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(KapiTheme.textSecondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 8)], spacing: 8) {
                    ForEach(store.tags, id: \.self) { tag in
                        let count = store.transactions(forTag: tag).count
                        let isSelected = selectedFilterTag == tag
                        HStack(spacing: 4) {
                            Button {
                                selectedFilterTag = (selectedFilterTag == tag) ? nil : tag
                            } label: {
                                Text("#\(tag) (\(count))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : KapiTheme.textPrimary)
                                    .lineLimit(1)
                            }
                            Button {
                                store.deleteTag(tag)
                                if selectedFilterTag == tag { selectedFilterTag = nil }
                                statusBannerMessage = "已删除标签: #\(tag)"
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : KapiTheme.textMuted)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isSelected ? KapiTheme.expenseBlue : Color.white))
                    }
                }
            }

            if let activeTag = selectedFilterTag {
                let taggedBills = store.transactions(forTag: activeTag)
                VStack(alignment: .leading, spacing: 8) {
                    Text("🏷️ 标签「#\(activeTag)」下的全部账单 (\(taggedBills.count) 笔)：")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(KapiTheme.textPrimary)

                    if taggedBills.isEmpty {
                        Text("该标签下暂无账单记录")
                            .font(.system(size: 12))
                            .foregroundColor(KapiTheme.textMuted)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(taggedBills) { item in
                            HStack {
                                Text(item.categoryPath)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(item.note)
                                    .font(.system(size: 11))
                                    .foregroundColor(KapiTheme.textMuted)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.type == .expense ? "-\(KapiTheme.formatRM(item.amount))" : "+\(KapiTheme.formatRM(item.amount))")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(item.type == .expense ? KapiTheme.expenseBlue : KapiTheme.incomeOrange)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - 3. 定时记账 (Scheduled Bookkeeping Section)

    private var scheduledBookkeepingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("⏰ 定时记账与周期固定收支")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)
                Spacer()
                Button {
                    showCreateScheduledSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("新增计划")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(KapiTheme.expenseBlue)
                }
            }

            Text("针对房租、宽带、月薪、订阅会员等固定周期收支，到期自动入账或一键执行，告别重复手工输入。")
                .font(.system(size: 12))
                .foregroundColor(KapiTheme.textSecondary)

            ForEach(store.scheduledTransactions) { item in
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Text(item.iconName)
                            .font(.system(size: 24))
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(KapiTheme.textPrimary)
                            Text("\(item.frequency.rawValue) \(item.dayOfMonth)日 · \(item.accountName) · \(item.categoryPath)")
                                .font(.system(size: 11))
                                .foregroundColor(KapiTheme.textSecondary)
                        }

                        Spacer()

                        Text(item.type == .expense ? "-\(KapiTheme.formatRM(item.amount))" : "+\(KapiTheme.formatRM(item.amount))")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(item.type == .expense ? KapiTheme.expenseBlue : KapiTheme.incomeOrange)
                    }

                    Divider()

                    HStack {
                        Toggle(isOn: Binding(
                            get: { item.isEnabled },
                            set: { _ in store.toggleScheduledTransaction(id: item.id) }
                        )) {
                            Text(item.isEnabled ? "计划启用中" : "已暂停")
                                .font(.system(size: 12))
                                .foregroundColor(item.isEnabled ? KapiTheme.balanceGreen : KapiTheme.textMuted)
                        }

                        Spacer()

                        Button {
                            store.executeScheduledTransactionNow(id: item.id)
                            statusBannerMessage = "已立即执行并记入账本: \(item.title) \(KapiTheme.formatRM(item.amount))"
                        } label: {
                            Text("⚡ 立即入账一次")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(KapiTheme.expenseBlue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color(hex: 0xE8F0FE)))
                        }

                        Button {
                            store.deleteScheduledTransaction(id: item.id)
                            statusBannerMessage = "已删除定时计划: \(item.title)"
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(KapiTheme.dangerRed)
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            }
        }
        .sheet(isPresented: $showCreateScheduledSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Text("计划名称")
                        .font(.system(size: 13, weight: .semibold))
                    TextField("如：每月房贷 / Netflix 会员", text: $newScheduledTitle)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("类型")
                                .font(.system(size: 13, weight: .semibold))
                            Picker("", selection: $newScheduledType) {
                                Text("支出").tag(TransactionType.expense)
                                Text("收入").tag(TransactionType.income)
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("金额 (RM)")
                                .font(.system(size: 13, weight: .semibold))
                            TextField("100.00", text: $newScheduledAmount)
                                .font(.system(size: 14))
                                .padding(7)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))
                        }
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("扣款/入账账户")
                                .font(.system(size: 13, weight: .semibold))
                            Picker("", selection: $newScheduledAccount) {
                                ForEach(store.accounts) { acc in
                                    Text(acc.name).tag(acc.name)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("执行周期")
                                .font(.system(size: 13, weight: .semibold))
                            Picker("", selection: $newScheduledFreq) {
                                ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                                    Text(freq.rawValue).tag(freq)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    Button {
                        let trimmed = newScheduledTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, let amt = Double(newScheduledAmount), amt > 0 else { return }
                        let newItem = ScheduledTransactionItem(
                            title: trimmed,
                            type: newScheduledType,
                            amount: amt,
                            categoryPath: newScheduledType == .expense ? "住房-房租房贷" : "职业收入-绩效奖金",
                            iconName: newScheduledType == .expense ? "🏠" : "💼",
                            accountName: newScheduledAccount,
                            frequency: newScheduledFreq,
                            dayOfMonth: 1,
                            isEnabled: true
                        )
                        store.addScheduledTransaction(newItem)
                        newScheduledTitle = ""
                        newScheduledAmount = ""
                        showCreateScheduledSheet = false
                        statusBannerMessage = "已创建定时入账计划: \(trimmed)"
                    } label: {
                        Text("保存定时计划")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(KapiTheme.expenseBlue))
                    }
                    .padding(.top, 10)

                    Spacer()
                }
                .padding(16)
                .navigationTitle("新增定时记账")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showCreateScheduledSheet = false }
                    }
                }
            }
            .presentationDetents([.height(380)])
        }
    }

    // MARK: - 4. 小组件展示与配置 (Widgets Showcase Section)

    private var widgetsShowcaseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("🧩 iOS 桌面与锁屏小组件")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(KapiTheme.textPrimary)

            Text("在 iPhone 桌面长按进入编辑状态 ➔ 点击左上角「+」➔ 搜索「咔皮记账」，即可添加以下官方设计小组件：")
                .font(.system(size: 12))
                .foregroundColor(KapiTheme.textSecondary)

            // 1. Small Widget Preview (今日可用)
            VStack(alignment: .leading, spacing: 10) {
                Text("小号小组件 · 今日动态预算")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)

                HStack {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: 0xEEF0F6), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        Circle()
                            .trim(from: 0, to: 0.65)
                            .stroke(KapiTheme.expenseBlue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 80, height: 80)
                        VStack(spacing: 2) {
                            Text("今日可用")
                                .font(.system(size: 9))
                                .foregroundColor(KapiTheme.textSecondary)
                            Text("RM92.26")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(KapiTheme.textPrimary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("🦫 动态结余滚入")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(KapiTheme.expenseBlue)
                        Text("今日已花费 RM0.00")
                            .font(.system(size: 10))
                            .foregroundColor(KapiTheme.textMuted)
                        Text("实时同步当前账本")
                            .font(.system(size: 10))
                            .foregroundColor(KapiTheme.textMuted)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            }

            // 2. Medium Widget Preview (7日趋势与本周收支)
            VStack(alignment: .leading, spacing: 10) {
                Text("中号小组件 · 7日收支趋势")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(KapiTheme.textPrimary)

                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("本周结余")
                            .font(.system(size: 10))
                            .foregroundColor(KapiTheme.textSecondary)
                        Text(KapiTheme.formatRM(store.netWorth))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(KapiTheme.balanceGreen)
                    }
                    Spacer()
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach([0.2, 0.45, 0.3, 0.65, 0.85, 0.4, 0.95], id: \.self) { level in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(KapiTheme.expenseBlue.opacity(0.8))
                                .frame(width: 12, height: CGFloat(level * 42))
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            }
        }
    }

    // MARK: - 5. 通用设置 (General Settings Section)

    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("⚙️ 通用与偏好设置")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(KapiTheme.textPrimary)

            // Nickname
            VStack(alignment: .leading, spacing: 8) {
                Text("用户昵称")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KapiTheme.textSecondary)
                HStack {
                    TextField("输入您的昵称", text: $editingNickname)
                        .font(.system(size: 14))
                    Button("保存") {
                        store.setNickname(editingNickname)
                        statusBannerMessage = "已更新昵称为: \(store.userNickname)"
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(KapiTheme.expenseBlue))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            }
            .onAppear {
                editingNickname = store.userNickname
            }

            // Haptics Toggle
            Toggle(isOn: $store.hapticsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("触觉震动反馈")
                        .font(.system(size: 14, weight: .medium))
                    Text("在点击按键与确认记账时提供清脆震动反馈")
                        .font(.system(size: 11))
                        .foregroundColor(KapiTheme.textMuted)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))

            // Account Initial Balances Quick Settings Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("💳 账户起始金额与开局资产")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(KapiTheme.textPrimary)
                    Spacer()
                    Text("净资产: \(KapiTheme.formatRM(store.netWorth))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(KapiTheme.expenseBlue)
                }

                Text("在此设定各资金账户（现金、银行卡、电子钱包）现实生活中的初始开局金额。日常记账时将在此基准上实时增减。")
                    .font(.system(size: 11))
                    .foregroundColor(KapiTheme.textMuted)

                ForEach(store.accounts) { account in
                    AccountInitialBalanceRow(account: account, store: store)
                    if account.id != store.accounts.last?.id {
                        Divider()
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))

            // Storage mode info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("数据存储模式")
                        .font(.system(size: 14, weight: .medium))
                    Text("本地安全独立沙盒存储，无需联网即可完整离线使用")
                        .font(.system(size: 11))
                        .foregroundColor(KapiTheme.textMuted)
                }
                Spacer()
                Text("离线安全")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(KapiTheme.balanceGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: 0xE8F5E9)))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))

            dataManagementCard
        }
    }
}

public struct AccountInitialBalanceRow: View {
    public let account: AccountItem
    @ObservedObject public var store: KapiStore
    @State private var balanceInput: String = ""
    @State private var isEditing: Bool = false

    public init(account: AccountItem, store: KapiStore) {
        self.account = account
        self.store = store
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(account.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KapiTheme.textPrimary)
                .frame(width: 100, alignment: .leading)

            Spacer()

            if isEditing {
                Text("RM")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(KapiTheme.textSecondary)

                TextField("0.00", text: $balanceInput)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(width: 75)
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(KapiTheme.expenseBlue, lineWidth: 1))

                Button("保存") {
                    if let val = Double(balanceInput) {
                        store.updateAccountBalance(accountName: account.name, newBalance: val)
                    }
                    isEditing = false
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(KapiTheme.expenseBlue))
            } else {
                Text(KapiTheme.formatRM(account.balance))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(KapiTheme.textPrimary)

                Button {
                    balanceInput = String(format: "%.2f", account.balance)
                    isEditing = true
                } label: {
                    Text("设定")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(KapiTheme.expenseBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: 0xEAF1FF)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 3)
        .onAppear {
            balanceInput = String(format: "%.2f", account.balance)
        }
    }
}
