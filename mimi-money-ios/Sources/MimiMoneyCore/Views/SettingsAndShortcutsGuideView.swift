import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

public struct SettingsAndShortcutsGuideView: View {
    @ObservedObject public var store: MimiStore
    @ObservedObject public var aiEngine: MimiAIEngine
    public var initialSectionTitle: String
    public var onDismiss: () -> Void
    public var onModifyTransactionFromPopup: (TransactionItem) -> Void

    @State private var simulatedSnippetTx: TransactionItem?
    /// 剪贴板识别出的待确认草稿（点确认才入账；不再识别完直接落账）
    @State private var pendingClipboardDraft: ParsedDraftBill?
    @State private var statusBannerMessage: String?
    @State private var showFileImporter: Bool = false
    @State private var showImportModal: Bool = false
    @State private var showExportModal: Bool = false
    @State private var exportPeriodOption: String = "全部"
    @State private var exportStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var exportEndDate: Date = Date()
    @State private var importInputText: String = ""
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

    // AI 识别引擎设置（当前试用 Groq 识图；key 只存 iOS Keychain）
    @State private var groqKeyInput: String = GroqSettings.apiKey ?? ""
    @State private var groqModelInput: String = GroqSettings.modelName
    @State private var groqTestStatus: String? = nil
    @State private var groqIsTesting: Bool = false

    public init(
        store: MimiStore,
        aiEngine: MimiAIEngine,
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
                                .foregroundColor(MimiTheme.balanceGreen)
                            Text(banner)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(MimiTheme.textPrimary)
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
                    default: // 自动记账（API 已迁到设置）
                        shortcutsCard
                    }
                }
                .padding(16)
            }
            .background(MimiTheme.background.ignoresSafeArea())
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
            .sheet(isPresented: $showImportModal) {
                importModalSheet
            }
            .sheet(isPresented: $showExportModal) {
                exportModalSheet
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

    // MARK: - CSV Import & Export Card (极简两个按钮：导入 或 导出)

    private var csvImportExportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("账单导入与导出")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
            }

            Text("导入支持查看标准模版并直接输入或粘贴数据；导出支持灵活选择时间段（全部/本月/上月/本年/自定义）。")
                .font(.system(size: 12))
                .foregroundColor(MimiTheme.textSecondary)

            HStack(spacing: 12) {
                // Button 1: 导入账单
                Button {
                    importInputText = ""
                    showImportModal = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 15))
                        Text("📥 导入账单")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.expenseBlue))
                }
                .buttonStyle(.plain)

                // Button 2: 导出账单
                Button {
                    showExportModal = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.system(size: 15))
                        Text("📤 导出账单")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.incomeOrange))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - Import Modal Sheet

    private var importModalSheet: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(MimiTheme.expenseBlue)
                            Text("标准 CSV 格式模版")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(MimiTheme.textPrimary)
                            Spacer()
                            Button {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = standardCSVTemplate
                                statusBannerMessage = "已复制标准 CSV 模版到剪贴板"
                                #endif
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                    Text("复制模版")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(MimiTheme.expenseBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color(hex: 0xE8F0FE)))
                            }
                            .buttonStyle(.plain)
                        }

                        Text("日期,时间,类型,金额,一级分类,二级分类,账户,备注\n2026-11-08,21:59:00,支出,38.78,交通,加油充电,PBBank,加油\n2026-11-08,16:56:34,支出,5.90,餐饮,餐厅,TNG eWallet,买egglab的东西\n2026-11-06,10:00:00,收入,1148.31,职业收入,工资,CIMB,月度薪资")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(MimiTheme.textSecondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("用户输入区域 (粘贴或输入 CSV 数据)：")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(MimiTheme.textPrimary)
                            Spacer()
                            Button("从剪贴板粘贴") {
                                #if canImport(UIKit)
                                if let str = UIPasteboard.general.string, !str.isEmpty {
                                    importInputText = str
                                }
                                #endif
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(MimiTheme.expenseBlue)
                        }

                        TextEditor(text: $importInputText)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.25), lineWidth: 1))

                        HStack(spacing: 10) {
                            Button {
                                showFileImporter = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                    Text("选择 CSV 文件")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(MimiTheme.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xF0F2F6)))
                            }
                            .buttonStyle(.plain)

                            Button {
                                importInputText = MimiCSVService.userExportedCSV
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text("填入 151 笔真实备份样例")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: 0x2E7D32))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xE8F5E9)))
                            }
                            .buttonStyle(.plain)
                        }

                        Toggle("覆盖清空现有账单（若关闭则追加合并）", isOn: $replaceExistingOnImport)
                            .font(.system(size: 12))
                            .foregroundColor(MimiTheme.textSecondary)
                            .padding(.top, 4)
                    }

                    Button {
                        let trimmed = importInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let count = store.importMimiCSV(trimmed, replaceExisting: replaceExistingOnImport)
                        showImportModal = false
                        statusBannerMessage = "已成功导入 \(count) 笔账单记录"
                    } label: {
                        Text("确认导入")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.expenseBlue))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .navigationTitle("导入账单")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showImportModal = false }
                }
            }
        }
    }

    private var standardCSVTemplate: String {
        """
        日期,时间,类型,金额,一级分类,二级分类,账户,备注
        2026-11-08,21:59:00,支出,38.78,交通,加油充电,PBBank,加油
        2026-11-08,16:56:34,支出,5.90,餐饮,餐厅,TNG eWallet,买egglab的东西
        2026-11-06,10:00:00,收入,1148.31,职业收入,工资,CIMB,月度薪资
        """
    }

    // MARK: - Export Modal Sheet (支持选择时间段导出)

    private var exportModalSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("选择要导出的时间段：")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)

                HStack(spacing: 8) {
                    ForEach(["全部", "本月", "上月", "本年", "自定义"], id: \.self) { opt in
                        Button {
                            exportPeriodOption = opt
                        } label: {
                            Text(opt)
                                .font(.system(size: 12, weight: exportPeriodOption == opt ? .bold : .medium))
                                .foregroundColor(exportPeriodOption == opt ? .white : MimiTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(exportPeriodOption == opt ? MimiTheme.incomeOrange : Color(hex: 0xF0F2F6))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if exportPeriodOption == "自定义" {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("开始日期")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(MimiTheme.textSecondary)
                            Spacer()
                            MimiDateFieldButton(
                                date: $exportStartDate,
                                mode: .date,
                                title: "开始日期"
                            )
                        }
                        HStack {
                            Text("结束日期")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(MimiTheme.textSecondary)
                            Spacer()
                            MimiDateFieldButton(
                                date: $exportEndDate,
                                mode: .date,
                                title: "结束日期"
                            )
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF7F8FA)))
                }

                let filtered = filteredTransactionsForExport()
                let exp = filtered.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
                let inc = filtered.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }

                VStack(alignment: .leading, spacing: 6) {
                    Text("当前所选时间段统计：")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(MimiTheme.textSecondary)
                    HStack(spacing: 12) {
                        Text("共 \(filtered.count) 笔账单")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MimiTheme.textPrimary)
                        Text("支 \(MimiTheme.formatRM(exp))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(MimiTheme.expenseBlue)
                        Text("收 \(MimiTheme.formatRM(inc))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(MimiTheme.incomeOrange)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF5F6FA)))

                Spacer()

                let csvData = store.exportMimiCSV(startDate: exportDateRange.start, endDate: exportDateRange.end)

                ShareLink(
                    item: csvData,
                    preview: SharePreview("MimiMoney_Export_\(exportPeriodOption).csv", image: Image(systemName: "tablecells"))
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("📤 导出并分享 CSV 文件")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(MimiTheme.incomeOrange))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .navigationTitle("导出账单")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showExportModal = false }
                }
            }
        }
    }

    private var exportDateRange: (start: Date?, end: Date?) {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        switch exportPeriodOption {
        case "本月":
            var comps = cal.dateComponents([.year, .month], from: now)
            comps.day = 1
            let start = cal.date(from: comps)
            comps.month = (comps.month ?? 1) + 1
            comps.day = 0
            comps.hour = 23
            comps.minute = 59
            comps.second = 59
            let end = cal.date(from: comps)
            return (start, end)
        case "上月":
            var comps = cal.dateComponents([.year, .month], from: now)
            comps.month = (comps.month ?? 1) - 1
            comps.day = 1
            let start = cal.date(from: comps)
            comps.month = (comps.month ?? 1) + 1
            comps.day = 0
            comps.hour = 23
            comps.minute = 59
            comps.second = 59
            let end = cal.date(from: comps)
            return (start, end)
        case "本年":
            let y = cal.component(.year, from: now)
            let start = cal.date(from: DateComponents(year: y, month: 1, day: 1))
            let end = cal.date(from: DateComponents(year: y, month: 12, day: 31, hour: 23, minute: 59, second: 59))
            return (start, end)
        case "自定义":
            return (exportStartDate, exportEndDate)
        default:
            return (nil, nil)
        }
    }

    /// 指南页效果预览用的示例账单（与预览卡上写死的示例为同一笔）：
    /// 直接按结构构造，不再经任何文字解析。
    fileprivate static func demoSampleDraft() -> ParsedDraftBill {
        GeminiBillDTO(
            type: "expense",
            amount: 5.90,
            counterparty: "Near Me Voucher Eggette Lab",
            counterpartyKind: "merchant",
            account: "TNGewallet",
            primaryCategory: "餐饮",
            subCategory: "零食甜品",
            occurredAt: "2026-11-08 16:56",
            note: ""
        ).toDraftBill(now: Date())
    }

    private func filteredTransactionsForExport() -> [TransactionItem] {
        let range = exportDateRange
        if let s = range.start, let e = range.end {
            return store.transactions.filter { $0.date >= s && $0.date <= e }
        } else if let s = range.start {
            return store.transactions.filter { $0.date >= s }
        } else if let e = range.end {
            return store.transactions.filter { $0.date <= e }
        }
        return store.transactions
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
            importInputText = content
            let count = store.importMimiCSV(content, replaceExisting: replaceExistingOnImport)
            statusBannerMessage = "已从文件成功导入 \(count) 笔账单记录"
        } catch {
            statusBannerMessage = "读取 CSV 文件失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 自动记账指南状态

    @State private var expandedTriggerSection: Int? = 4
    @State private var showShortcutTutorial: Bool = false
    @Environment(\.openURL) private var openURL

    // MARK: - 自动记账指南（截屏识别 + 四种触发；去掉未接入的语音记账）

    private func guideStepRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(MimiTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func triggerSection(index: Int, title: String, symbol: String, steps: [String]) -> some View {
        let expanded = expandedTriggerSection == index
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedTriggerSection = expanded ? nil : index
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(MimiTheme.expenseBlue)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color(hex: 0xE8F0FE)))
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(MimiTheme.textPrimary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MimiTheme.textMuted)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                        guideStepRow(step)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xF7F8FA)))
    }

    /// Gold compact row for secondary trigger methods (②③)
    private func compactTriggerRow(index: Int, title: String, steps: [String]) -> some View {
        let expanded = expandedTriggerSection == index
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedTriggerSection = expanded ? nil : index
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MimiTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MimiTheme.textMuted)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                        guideStepRow(step)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: 0xECEEF3), lineWidth: 1)
        )
    }

    private var shortcutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("自动记账 · 截屏识别记账")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(MimiTheme.textPrimary)

            Text("付款完成后触发一次「咪咪记账 · 识别账单」快捷指令：系统自动截屏 → AI 识别金额、商户与扣款账户 → 在当前付款 App 上方弹出卡片。点「修改」跳进 App 编辑；点「确认」原地入账。下方四种触发方式任选一种绑定即可。也可直接用「读取剪贴板截图」。")
                .font(.system(size: 12))
                .foregroundColor(MimiTheme.textSecondary)

            triggerSection(
                index: 1,
                title: "① 通过辅助触控触发",
                symbol: "circle.circle.fill",
                steps: [
                    "1. 先按下方「教程」把「识别账单」捷徑建好（只需一次）",
                    "2. 打开 iPhone「设置 → 辅助功能 → 触控 → 辅助触控」，开启辅助触控",
                    "3. 为「单点」「轻点两下」或「长按」选择刚建好的捷徑",
                    "4. 付款完成后，使用该手势触发记账"
                ]
            )

            // Gold: ②③ often appear as compact chevron rows
            compactTriggerRow(
                index: 2,
                title: "② 通过「轻敲手机背面」触发",
                steps: [
                    "1. 先按下方「教程」把「识别账单」捷徑建好（只需一次）",
                    "2. 打开 iPhone「设置 → 辅助功能 → 触控」，拉到最底部点「轻点背面」",
                    "3. 选择「轻点两下」或「轻点三下」，勾选刚建好的捷徑",
                    "4. 付款完成后，敲两下手机背面即可触发记账"
                ]
            )

            compactTriggerRow(
                index: 3,
                title: "③ 通过「操作按钮」触发",
                steps: [
                    "1. 先按下方「教程」把「识别账单」捷徑建好（只需一次）",
                    "2. 打开 iPhone「设置 → 操作按钮」，选择「快捷指令」（需 iPhone 15 Pro 或更新机型）",
                    "3. 点「选取」，选择刚建好的捷徑",
                    "4. 付款完成后，按一下侧边操作按钮即可触发记账"
                ]
            )

            triggerSection(
                index: 4,
                title: "④ 通过「控制中心」触发（添加专属指令）",
                symbol: "switch.2",
                steps: [
                    "仅部分 iOS 版本支持（建议 iOS 18.1 及以上），若无法使用，建议升级系统版本",
                    "1. 点击下方「添加专属指令」，记住系统添加页显示的名称",
                    "2. 打开控制中心，长按进入编辑，点击「添加控制」",
                    "3. 添加「快捷指令」，点击「选取」，选择刚添加的咪咪记账控制中心快捷指令",
                    "4. 付款完成后，点击该控制触发记账"
                ]
            )

            // 「教程」与「添加专属指令」双按钮
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedTriggerSection = 4
                        showShortcutTutorial = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 15))
                        Text("教程")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(MimiTheme.expenseBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(hex: 0xE8F0FE)))
                }
                .buttonStyle(.plain)

                Button {
                    if let link = ShortcutActionCoordinator.shortcutInstallURL, let url = URL(string: link) {
                        openURL(url)
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedTriggerSection = 4
                            showShortcutTutorial = true
                        }
                    }
                } label: {
                    Text("添加专属指令")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(MimiTheme.expenseBlue))
                }
                .buttonStyle(.plain)
            }

            if ShortcutActionCoordinator.shortcutInstallURL == nil {
                Text("首次需按教程手动建一次；建好后在「快捷指令」App 中对该捷徑点「共享 → 拷贝 iCloud 链接」，把链接发给开发者即可开通一键导入。")
                    .font(.system(size: 11))
                    .foregroundColor(MimiTheme.textMuted)
            }

            if showShortcutTutorial {
                VStack(alignment: .leading, spacing: 6) {
                    Text("📖 手动搭建教程（只需一次，约 1 分钟）：")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(MimiTheme.textPrimary)
                    guideStepRow("1. 打开自带「快捷指令」App → 点右上角「+」新建，命名为「咪咪记账-识别账单」")
                    guideStepRow("2. 添加动作「隐藏控制中心 (Hide Control Centre)」")
                    guideStepRow("3. 添加动作「等待 (Wait)」，时长设为 1 秒")
                    guideStepRow("4. 添加动作「截屏 (Take Screenshot)」")
                    guideStepRow("5. 添加动作「从截屏获取图像 (Get Images from Screenshot)」")
                    guideStepRow("6. 添加动作「识别账单 (咪咪记账)」，将「内容 (Content)」设为上一步的「图像 (Images)」，「类型 (Type)」保持 2")
                    Text("⚠️ 点开「识别账单」的展开箭头，确认「运行时显示 (Show When Run)」与「运行时打开 (Open When Run)」两个开关都打开，识别卡片才会直接浮在当前付款 App 上方。")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MimiTheme.expenseBlue)
                    guideStepRow("完成后回到上方四种触发方式，任选一种把这个捷徑绑定上去即可使用。无需下载任何 .shortcut 文件：本 App 安装后系统已内置原生动作「识别账单」。")
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF5F6FA)))
            }

            // 快捷入口：直接打开快捷指令 App
            Button {
                ShortcutActionCoordinator.openShortcutsApp()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 16))
                    Text("打开「快捷指令」App 开始搭建")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.expenseBlue))
            }
            .buttonStyle(.plain)

            // 无需快捷指令：读取剪贴板截图 → 预览卡确认后才入账
            Button {
                #if canImport(UIKit)
                if let image = UIPasteboard.general.image, let pngData = image.pngData() {
                    Task {
                        do {
                            let result = try await SmartReceiptRecognizer.recognize(imageData: pngData)
                            await MainActor.run {
                                pendingClipboardDraft = result.draft
                                simulatedSnippetTx = ShortcutActionCoordinator.makeTransaction(
                                    from: result.draft,
                                    in: store,
                                    isConfirmed: false
                                )
                                if result.isSuspiciousAmount {
                                    statusBannerMessage = "已识别，但金额看起来不太对劲。请核对后点「确认」入账，或点「修改」编辑。"
                                } else {
                                    statusBannerMessage = "已识别剪贴板截图，请点卡片上的「确认」入账，或「修改」编辑。尚未记账。"
                                }
                            }
                        } catch {
                            await MainActor.run {
                                statusBannerMessage = (error as? ReceiptRecognitionFailure)?.dialogText
                                    ?? ReceiptRecognitionFailure.failed(reason: error.localizedDescription).dialogText
                            }
                        }
                    }
                } else {
                    statusBannerMessage = "剪贴板里没有截图：请先截屏付款页面，再点这个按钮。识别只走 AI，不会拿示例账单凑数。"
                }
                #endif
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 14))
                    Text("无需快捷指令 · 读取剪贴板截图（确认后入账）")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(MimiTheme.incomeOrange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xFFF3E0)))
            }
            .buttonStyle(.plain)

            // 识别卡片效果预览
            Text("效果预览（付款 App 上方弹出的卡片长这样）：")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(MimiTheme.textPrimary)

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
                    let draft = pendingClipboardDraft ?? Self.demoSampleDraft()
                    let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
                    pendingClipboardDraft = nil
                    _ = ShortcutActionCoordinator.markForInAppModification(transactionId: saved.id, in: store)
                    onModifyTransactionFromPopup(saved)
                },
                onConfirmTapped: {
                    let draft = pendingClipboardDraft ?? Self.demoSampleDraft()
                    let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
                    pendingClipboardDraft = nil
                    simulatedSnippetTx = saved
                    statusBannerMessage = "已确认记账：\(saved.categoryPath) \(MimiTheme.formatRM(saved.amount))"
                }
            )
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    // MARK: - AI / API（设置页精简版）

    private var aiEngineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI / API")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(MimiTheme.textSecondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Groq API Key")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MimiTheme.textSecondary)

                SecureField("粘贴 API Key", text: $groqKeyInput)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))
                    .autocorrectionDisabled(true)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif

                HStack(spacing: 10) {
                    TextField("模型", text: $groqModelInput)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))
                        .autocorrectionDisabled(true)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    Button {
                        AIEngineSettings.provider = .groq
                        GroqSettings.saveAPIKey(groqKeyInput)
                        GroqSettings.modelName = groqModelInput
                        groqTestStatus = "已保存"
                    } label: {
                        Text("保存")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(MimiTheme.expenseBlue))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    Button {
                        AIEngineSettings.provider = .groq
                        GroqSettings.saveAPIKey(groqKeyInput)
                        GroqSettings.modelName = groqModelInput
                        groqIsTesting = true
                        groqTestStatus = "测试中…"
                        Task {
                            let result = await GroqClient.testConnection()
                            await MainActor.run {
                                groqIsTesting = false
                                groqTestStatus = result.message
                            }
                        }
                    } label: {
                        Text(groqIsTesting ? "测试中…" : "测试连接")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MimiTheme.expenseBlue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color(hex: 0xE8F0FE)))
                    }
                    .buttonStyle(.plain)
                    .disabled(groqIsTesting)

                    if let groqTestStatus {
                        Text(groqTestStatus)
                            .font(.system(size: 12))
                            .foregroundColor(MimiTheme.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
        }
        .onAppear {
            AIEngineSettings.provider = .groq
            if groqModelInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                groqModelInput = GroqSettings.defaultModelName
            }
        }
    }

    // MARK: - Data Management Card

    private var dataManagementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📦 数据管理与账本工具")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(MimiTheme.textPrimary)

            Button {
                showResetCleanAlert = true
            } label: {
                HStack {
                    Text("清空全部账单与余额（恢复空白初始状态）")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MimiTheme.dangerRed)
                    Spacer()
                    Image(systemName: "trash")
                        .foregroundColor(MimiTheme.dangerRed)
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
                        .foregroundColor(MimiTheme.expenseBlue)
                    Spacer()
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(MimiTheme.expenseBlue)
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
                Text("全部账本 (\(store.ledgers.count))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
                Button {
                    showCreateLedgerSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("新建账本")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MimiTheme.expenseBlue)
                }
            }

            ForEach(store.ledgers) { ledger in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 18))
                            .foregroundColor(MimiTheme.vipGold)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(ledger.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(MimiTheme.textPrimary)
                                if ledger.id == store.currentLedgerId {
                                    Text("当前使用")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(MimiTheme.balanceGreen)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color(hex: 0xE8F5E9)))
                                }
                            }
                            Text("主币种: \(ledger.currency.rawValue) · 月预算: \(MimiTheme.formatRM(ledger.monthlyBudget))")
                                .font(.system(size: 11))
                                .foregroundColor(MimiTheme.textSecondary)
                        }
                        Spacer()

                        if ledger.id != store.currentLedgerId {
                            Button("切换") {
                                store.switchLedger(id: ledger.id)
                                statusBannerMessage = "已切换到账本: \(ledger.name)"
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(MimiTheme.expenseBlue)
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
                                .foregroundColor(MimiTheme.expenseBlue)
                        }

                        Spacer()

                        if store.ledgers.count > 1 {
                            Button {
                                store.deleteLedger(id: ledger.id)
                                statusBannerMessage = "已删除账本: \(ledger.name)"
                            } label: {
                                Text("删除")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(MimiTheme.dangerRed)
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
                        .foregroundColor(MimiTheme.textSecondary)
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
                            statusBannerMessage = "已更新账本预算为 \(MimiTheme.formatRM(val))"
                        }
                        editingLedgerForBudget = nil
                    } label: {
                        Text("保存预算")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(MimiTheme.expenseBlue))
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
                            .background(Capsule().fill(MimiTheme.expenseBlue))
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
            Text("标签管理 (\(store.tags.count))")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(MimiTheme.textPrimary)

            Text("为账单打上标签（如：报销、旅行、人情），可以在此统一统计与筛选。")
                .font(.system(size: 12))
                .foregroundColor(MimiTheme.textSecondary)

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
                .background(Capsule().fill(MimiTheme.expenseBlue))
            }

            // Tag chips
            VStack(alignment: .leading, spacing: 10) {
                Text("现有标签列表（点击标签可筛选关联账单）：")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(MimiTheme.textSecondary)

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
                                    .foregroundColor(isSelected ? .white : MimiTheme.textPrimary)
                                    .lineLimit(1)
                            }
                            Button {
                                store.deleteTag(tag)
                                if selectedFilterTag == tag { selectedFilterTag = nil }
                                statusBannerMessage = "已删除标签: #\(tag)"
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : MimiTheme.textMuted)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isSelected ? MimiTheme.expenseBlue : Color.white))
                    }
                }
            }

            if let activeTag = selectedFilterTag {
                let taggedBills = store.transactions(forTag: activeTag)
                VStack(alignment: .leading, spacing: 8) {
                    Text("🏷️ 标签「#\(activeTag)」下的全部账单 (\(taggedBills.count) 笔)：")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(MimiTheme.textPrimary)

                    if taggedBills.isEmpty {
                        Text("该标签下暂无账单记录")
                            .font(.system(size: 12))
                            .foregroundColor(MimiTheme.textMuted)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(taggedBills) { item in
                            HStack {
                                Text(item.categoryPath)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(item.note)
                                    .font(.system(size: 11))
                                    .foregroundColor(MimiTheme.textMuted)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.type == .expense ? "-\(MimiTheme.formatRM(item.amount))" : "+\(MimiTheme.formatRM(item.amount))")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(item.type == .expense ? MimiTheme.expenseBlue : MimiTheme.incomeOrange)
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
                Text("定时记账与周期固定收支")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
                Button {
                    showCreateScheduledSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("新增计划")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MimiTheme.expenseBlue)
                }
            }

            Text("针对房租、宽带、月薪、订阅会员等固定周期收支，到期自动入账或一键执行，告别重复手工输入。")
                .font(.system(size: 12))
                .foregroundColor(MimiTheme.textSecondary)

            if store.scheduledTransactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 28))
                        .foregroundColor(MimiTheme.textMuted)
                    Text("暂无定时记账计划")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(MimiTheme.textSecondary)
                    Text("点击右上角「+ 新增计划」添加房租、月薪、话费等固定周期账单")
                        .font(.system(size: 11))
                        .foregroundColor(MimiTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF7F8FA)))
            }

            ForEach(store.scheduledTransactions) { item in
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        MimiStickerIconView(
                            iconName: item.iconName,
                            categoryName: item.categoryPath,
                            transactionType: item.type,
                            size: 36
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(MimiTheme.textPrimary)
                            Text("\(item.frequency.rawValue) \(item.dayOfMonth)日 · \(item.accountName) · \(item.categoryPath)")
                                .font(.system(size: 11))
                                .foregroundColor(MimiTheme.textSecondary)
                        }

                        Spacer()

                        Text(item.type == .expense ? "-\(MimiTheme.formatRM(item.amount))" : "+\(MimiTheme.formatRM(item.amount))")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(item.type == .expense ? MimiTheme.expenseBlue : MimiTheme.incomeOrange)
                    }

                    Divider()

                    HStack {
                        Toggle(isOn: Binding(
                            get: { item.isEnabled },
                            set: { _ in store.toggleScheduledTransaction(id: item.id) }
                        )) {
                            Text(item.isEnabled ? "计划启用中" : "已暂停")
                                .font(.system(size: 12))
                                .foregroundColor(item.isEnabled ? MimiTheme.balanceGreen : MimiTheme.textMuted)
                        }

                        Spacer()

                        Button {
                            store.executeScheduledTransactionNow(id: item.id)
                            statusBannerMessage = "已立即执行并记入账本: \(item.title) \(MimiTheme.formatRM(item.amount))"
                        } label: {
                            Text("立即入账一次")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(MimiTheme.expenseBlue)
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
                                .foregroundColor(MimiTheme.dangerRed)
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
                            .background(Capsule().fill(MimiTheme.expenseBlue))
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
            Text("iOS 桌面与锁屏小组件")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(MimiTheme.textPrimary)

            Text("在 iPhone 桌面长按进入编辑状态 ➔ 点击左上角「+」➔ 搜索「咪咪记账」，即可添加以下官方设计小组件：")
                .font(.system(size: 12))
                .foregroundColor(MimiTheme.textSecondary)

            // 1. Small Widget Preview (今日可用)
            VStack(alignment: .leading, spacing: 10) {
                Text("小号小组件 · 今日动态预算")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)

                HStack {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: 0xEEF0F6), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(MimiTheme.expenseBlue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 80, height: 80)
                        VStack(spacing: 2) {
                            Text("今日可用")
                                .font(.system(size: 9))
                                .foregroundColor(MimiTheme.textSecondary)
                            Text(MimiTheme.formatRM(store.monthlyBudgetRemaining(year: 2026, month: 11) / 21.0))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(MimiTheme.textPrimary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("动态结余滚入")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(MimiTheme.expenseBlue)
                        Text("今日已花费 \(MimiTheme.formatRM(0))")
                            .font(.system(size: 10))
                            .foregroundColor(MimiTheme.textMuted)
                        Text("实时同步当前账本")
                            .font(.system(size: 10))
                            .foregroundColor(MimiTheme.textMuted)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                )
            }

            // 2. Medium Widget Preview (7日趋势与本周收支)
            VStack(alignment: .leading, spacing: 10) {
                Text("中号小组件 · 7日收支趋势")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)

                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("本周结余")
                            .font(.system(size: 10))
                            .foregroundColor(MimiTheme.textSecondary)
                        Text(MimiTheme.formatRM(store.netWorth))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(MimiTheme.balanceGreen)
                    }
                    Spacer()
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach([0.2, 0.45, 0.3, 0.65, 0.85, 0.4, 0.95], id: \.self) { level in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(MimiTheme.expenseBlue.opacity(0.8))
                                .frame(width: 12, height: CGFloat(level * 42))
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                )
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0xF7F8FA)))
    }

    // MARK: - 设置（资料 / API / 其他）

    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 资料
            VStack(alignment: .leading, spacing: 8) {
                Text("资料")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MimiTheme.textSecondary)

                HStack {
                    Text("昵称")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(MimiTheme.textPrimary)
                    TextField("jinghao", text: $editingNickname)
                        .font(.system(size: 14))
                        .multilineTextAlignment(.trailing)
                    Button("保存") {
                        store.setNickname(editingNickname)
                        statusBannerMessage = "已更新昵称"
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(MimiTheme.expenseBlue))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            }
            .onAppear {
                if store.userNickname == "景豪" || store.userNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    store.setNickname("jinghao")
                }
                editingNickname = store.userNickname
            }

            // AI / API
            aiEngineCard

            // 其他
            VStack(alignment: .leading, spacing: 8) {
                Text("其他")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MimiTheme.textSecondary)

                Toggle(isOn: $store.hapticsEnabled) {
                    Text("触觉反馈")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))

                Button {
                    showResetCleanAlert = true
                } label: {
                    HStack {
                        Text("清空全部数据")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MimiTheme.dangerRed)
                        Spacer()
                        Image(systemName: "trash")
                            .foregroundColor(MimiTheme.dangerRed)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xFFEBEE)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

