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
                    default: // 自动记账
                        shortcutsCard
                        aiEngineCard
                        csvImportExportCard
                        dataManagementCard
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
                Text("📁 账单导入与导出")
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
                        Text("🚀 确认导入")
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
                            Text("开始日期:")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            DatePicker("", selection: $exportStartDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        HStack {
                            Text("结束日期:")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            DatePicker("", selection: $exportEndDate, displayedComponents: .date)
                                .labelsHidden()
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

    // MARK: - Shortcuts Popup Card

    private var shortcutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("⚡ 自动记账 · 快捷指令截图弹窗 (IMG_2294)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
            }

            Text("在 iPhone「快捷指令」中绑定『截屏 ➔ 咪咪记账 · 识别账单』，付款后在控制中心点击或敲两下手机背面即可弹出以下卡片：点击「修改 (View)」直达 App 账单详情页，点击「确认 (Got it)」原地直接入账。")
                .font(.system(size: 12))
                .foregroundColor(MimiTheme.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("📌 控制中心 / 轻点背面无感记账配置（推荐）：")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)
                Text("1. 打开自带「快捷指令」App ➔ 点右上角「+」新建")
                    .font(.system(size: 12))
                Text("2. 依次添加以下动作：\n   ① 隐藏控制中心 (Hide Control Centre)\n   ② 等待 1 秒 (Wait 1 second)\n   ③ 截屏 (Take screenshot)\n   ④ 从截屏获取图像 (Get images from Screenshot)\n   ⑤ 识别账单 (咪咪记账)")
                    .font(.system(size: 12))
                    .foregroundColor(MimiTheme.textSecondary)
                Text("3. ⚠️ 最关键一步：点击【识别账单】展开箭头，务必将【运行时打开】(Open When Run) 切换为【关闭】！")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MimiTheme.dangerRed)
                Text("👉 关闭「运行时打开」后，快捷指令就会停留在当前画面（不会跳进App），在屏幕顶部浮出包含【修改 (View)】与【确认 (Got it)】两个按钮的 Dialog 卡片：按确认原地直接记账；按修改才会打开 App！")
                    .font(.system(size: 11))
                    .foregroundColor(MimiTheme.textSecondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xF5F6FA)))

            // iOS 15+ Unsigned Shortcut Notice & Dual Non-Jumping Dialog Guide
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                        .foregroundColor(MimiTheme.expenseBlue)
                    Text("💡 为什么提示「不支持导入未签名的快捷指令」？")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(MimiTheme.textPrimary)
                }

                Text("因为 iOS 限制从网页直接下载 .shortcut 文件。你完全不需要下载任何外部文件！本 App 安装后，系统已内置原生动作【识别账单】。请直接在自带「快捷指令」App 中搜索并添加【识别账单】即可（100% 官方支持，永不失效）！")
                    .font(.system(size: 11))
                    .foregroundColor(MimiTheme.textSecondary)

                Divider()

                // Mode 2: Shortcuts "Choose from Menu" Dialog
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("🛠️ 备用方式：快捷指令原生「从菜单中选取」对话框")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(MimiTheme.incomeOrange)
                    }
                    Text("1. 在快捷指令中依次添加：【截屏】➔【拷贝至剪贴板】")
                        .font(.system(size: 11))
                    Text("2. 添加【从菜单中选取】(Choose from Menu)，提示写「是否记入咪咪记账？」")
                        .font(.system(size: 11, weight: .semibold))
                    Text("   • 选项 ①「Got it」：内部留空 ➔ 100% 停留在当前App，不跳转！\n   • 选项 ②「Edit」：内部添加【打开 URL】mimimoney://quick-scan ➔ 只有按此才跳转！")
                        .font(.system(size: 11))
                        .foregroundColor(MimiTheme.textSecondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))

                HStack {
                    Text("URL: mimimoney://quick-scan")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(MimiTheme.expenseBlue)
                    Spacer()
                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = "mimimoney://quick-scan"
                        statusBannerMessage = "已复制 URL: mimimoney://quick-scan"
                        #endif
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("复制链接")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(MimiTheme.expenseBlue))
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xF5F6FA)))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xFFF9E6)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.35), lineWidth: 1))

            // 1. One-click open apple shortcuts app
            Button {
                ShortcutActionCoordinator.openShortcutsApp()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 16))
                    Text("⚡ 打开「快捷指令」App 配置「识别账单」")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.expenseBlue))
            }
            .buttonStyle(.plain)

            // 2. Unsigned shortcut warning note
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Color.orange)
                    Text("为什么提示「不支持导入未签名的快捷指令」？")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MimiTheme.textPrimary)
                }
                Text("因为 iOS 限制从网页直接下载 .shortcut 文件。你完全不需要下载任何外部文件！本 App 安装后，系统已内置原生动作【识别账单】。请直接在自带「快捷指令」App 中搜索并添加【识别账单】即可（100% 官方支持，永不失效）！")
                    .font(.system(size: 11))
                    .foregroundColor(MimiTheme.textSecondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xFFF9E6)))

            // 3. Direct In-App Instant Recognition (No shortcut needed at all!)
            Button {
                #if canImport(UIKit)
                if let image = UIPasteboard.general.image, let pngData = image.pngData() {
                    let draft = ReceiptOCRService.recognizeAndParseImageSync(pngData)
                    let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
                    simulatedSnippetTx = saved
                    statusBannerMessage = "已通过 Apple Vision 成功识别剪贴板账单截图并记账！"
                } else if let clipStr = UIPasteboard.general.string, !clipStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let draft = ReceiptOCRService.parseReceiptText(clipStr)
                    let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
                    simulatedSnippetTx = saved
                    statusBannerMessage = "已识别剪贴板账单文字并记账！"
                } else {
                    let demoDraft = ReceiptOCRService.parseReceiptText(
                        "-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34"
                    )
                    let saved = ShortcutActionCoordinator.recordRecognizedDraft(demoDraft, in: store)
                    simulatedSnippetTx = saved
                    statusBannerMessage = "剪贴板无截图，已演示默认截图识别"
                }
                #endif
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 14))
                    Text("📸 无需快捷指令 · 一键读取剪贴板截图直接记账")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(MimiTheme.incomeOrange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xFFF3E0)))
            }
            .buttonStyle(.plain)

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
                .foregroundColor(MimiTheme.textPrimary)

            Text("已内置离线多笔拆单、Vision 账单 OCR 与财务官问答引擎（开箱即用，无需配置）。如需接入自定义大模型，可在下方填写：")
                .font(.system(size: 12))
                .foregroundColor(MimiTheme.textSecondary)

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
                Text("📒 全部账本 (\(store.ledgers.count))")
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
                        Text("📒")
                            .font(.system(size: 20))
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
            Text("🏷️ 标签管理 (\(store.tags.count))")
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
                Text("⏰ 定时记账与周期固定收支")
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
                        Text(item.iconName)
                            .font(.system(size: 24))
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF5F6FA)))

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
                            Text("⚡ 立即入账一次")
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
            Text("🧩 iOS 桌面与锁屏小组件")
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
                            .trim(from: 0, to: 0.65)
                            .stroke(MimiTheme.expenseBlue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 80, height: 80)
                        VStack(spacing: 2) {
                            Text("今日可用")
                                .font(.system(size: 9))
                                .foregroundColor(MimiTheme.textSecondary)
                            Text("RM92.26")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(MimiTheme.textPrimary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("🦫 动态结余滚入")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(MimiTheme.expenseBlue)
                        Text("今日已花费 RM0.00")
                            .font(.system(size: 10))
                            .foregroundColor(MimiTheme.textMuted)
                        Text("实时同步当前账本")
                            .font(.system(size: 10))
                            .foregroundColor(MimiTheme.textMuted)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
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
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            }
        }
    }

    // MARK: - 5. 通用设置 (General Settings Section)

    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("⚙️ 通用与偏好设置")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(MimiTheme.textPrimary)

            // Nickname
            VStack(alignment: .leading, spacing: 8) {
                Text("用户昵称")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MimiTheme.textSecondary)
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
                    .background(Capsule().fill(MimiTheme.expenseBlue))
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
                        .foregroundColor(MimiTheme.textMuted)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))

            // Account Initial Balances Quick Settings Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("💳 账户起始金额与开局资产")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MimiTheme.textPrimary)
                    Spacer()
                    Text("净资产: \(MimiTheme.formatRM(store.netWorth))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(MimiTheme.expenseBlue)
                }

                Text("在此设定各资金账户（现金、银行卡、电子钱包）现实生活中的初始开局金额。日常记账时将在此基准上实时增减。")
                    .font(.system(size: 11))
                    .foregroundColor(MimiTheme.textMuted)

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
                        .foregroundColor(MimiTheme.textMuted)
                }
                Spacer()
                Text("离线安全")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(MimiTheme.balanceGreen)
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
    @ObservedObject public var store: MimiStore
    @State private var balanceInput: String = ""
    @State private var editMode: Int = 0 // 0: 设定起始资金 (记账前), 1: 设定当前余额 (卡里现在)
    @State private var isEditing: Bool = false

    public init(account: AccountItem, store: MimiStore) {
        self.account = account
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(account.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MimiTheme.textPrimary)
                    .frame(width: 90, alignment: .leading)

                Spacer()

                if isEditing {
                    Picker("模式", selection: $editMode) {
                        Text("起始资金").tag(0)
                        Text("当前余额").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)

                    TextField("0.00", text: $balanceInput)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(width: 65)
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(MimiTheme.expenseBlue, lineWidth: 1))

                    Button("保存") {
                        if let val = Double(balanceInput) {
                            if editMode == 0 {
                                store.setAccountInitialBalance(accountId: account.id, initialBalance: val)
                            } else {
                                store.updateAccountBalance(accountId: account.id, newBalance: val)
                            }
                        }
                        isEditing = false
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(MimiTheme.expenseBlue))
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(MimiTheme.formatRM(account.balance))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(account.balance < -0.0001 ? Color(hex: 0xE53935) : MimiTheme.textPrimary)

                        Text("起始: \(MimiTheme.formatRM(account.initialBalance))")
                            .font(.system(size: 10))
                            .foregroundColor(MimiTheme.textMuted)
                    }

                    Button {
                        balanceInput = String(format: "%.2f", account.initialBalance)
                        editMode = 0
                        isEditing = true
                    } label: {
                        Text("设置")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(MimiTheme.expenseBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(hex: 0xEAF1FF)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 3)
        .onAppear {
            balanceInput = String(format: "%.2f", account.initialBalance)
        }
    }
}
