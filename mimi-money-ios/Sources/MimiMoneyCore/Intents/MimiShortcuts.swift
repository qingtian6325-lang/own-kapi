import Foundation
import SwiftUI
#if canImport(AppIntents)
import AppIntents
#endif
#if canImport(UIKit)
import UIKit
#endif

public struct ShortcutExecutionOutcome: Equatable, Sendable {
    public let transactionId: UUID
    public let draft: ParsedDraftBill
    public let didOpenAppForEditing: Bool

    public init(transactionId: UUID, draft: ParsedDraftBill, didOpenAppForEditing: Bool) {
        self.transactionId = transactionId
        self.draft = draft
        self.didOpenAppForEditing = didOpenAppForEditing
    }
}

// MARK: - Scan Confirmation Follow-Up Decision (v1.1.3)

/// 确认卡交互结束后的动作决策（纯逻辑，可单测）。
///
/// v1.1.3 起确认卡的系统按钮对改名为 View / Got it（与 Kapi 一致）：
/// 点「Got it」（accept）时 requestConfirmation 正常返回，随后落盘结束；
/// 点「View」（deny）或下滑关卡时，系统以同一种「取消」信号抛错回来，
/// 两者无法区分——按产品决策统一当作「去修改」：不落正式账，
/// 改为打开 App 到这笔的编辑页。其他错误则作废这笔，安静结束。
public enum ScanConfirmationFollowUp: Equatable, Sendable {
    /// 点了「View」或下滑关卡：打开 App 改这笔（暂存转未确认记录）。
    case openEditor
    /// 其他错误：作废暂存，不落盘、不打开 App。
    case discard

    public static func followUp(for error: Error) -> ScanConfirmationFollowUp {
        isCancellation(error) ? .openEditor : .discard
    }

    /// 取消类错误的判定：requestConfirmation 被拒绝/取消时按官方约定抛
    /// CancellationError；个别系统路径可能换一种错误类型回传，故再按
    /// 错误类型名含 "cancel" 兜底（只认类型名，避免把无关 NSError 误判）。
    public static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        return String(describing: type(of: error)).localizedCaseInsensitiveContains("cancel")
    }
}

@MainActor
public enum ShortcutActionCoordinator {
    /// 「添加专属指令」一键导入链接（iCloud 快捷指令分享链接，形如 https://www.icloud.com/shortcuts/xxxx）。
    /// 该链接只能由登录 iCloud 的设备在「快捷指令」App 内通过「共享 → 拷贝 iCloud 链接」生成，
    /// 服务器端无法伪造；在用户提供链接之前保持 nil，指南页的「添加专属指令」按钮将展开手动搭建教程。
    public static let shortcutInstallURL: String? = nil

    /// 把识别草稿构建为 TransactionItem（含收据图保存），但不落盘。
    public static func makeTransaction(from draft: ParsedDraftBill, in store: MimiStore, isConfirmed: Bool) -> TransactionItem {
        var attachments: [String] = []
        if let raw = draft.rawImageData {
            let filename = store.saveReceiptImage(data: raw)
            attachments.append(filename)
        }
        return TransactionItem(
            type: draft.type,
            categoryPath: draft.categoryPath,
            iconName: draft.iconName,
            amount: draft.amount,
            accountName: draft.accountName,
            note: draft.note,
            receiptImageLabels: attachments,
            date: draft.date,
            isConfirmed: isConfirmed
        )
    }

    public static func recordRecognizedDraft(_ draft: ParsedDraftBill, in store: MimiStore) -> TransactionItem {
        let tx = makeTransaction(from: draft, in: store, isConfirmed: true)
        store.addTransaction(tx)
        return tx
    }

    /// 确认型流程第一步（v1.1.2）：识别结果先暂存（isConfirmed=false），
    /// 不落盘、不计入余额/列表，等用户在系统确认卡上做决定。
    public static func stageRecognizedDraft(_ draft: ParsedDraftBill, in store: MimiStore) -> TransactionItem {
        let tx = makeTransaction(from: draft, in: store, isConfirmed: false)
        store.stagePendingScan(tx)
        return tx
    }

    /// 确认型流程第二步（用户点系统「确认」后）：消费暂存并以正式账单落盘。
    /// 暂存已被「修改」路径消费时返回 nil，绝不重复记账。
    @discardableResult
    public static func finalizePendingScan(id: UUID, in store: MimiStore) -> TransactionItem? {
        guard let staged = store.consumePendingScan(id: id) else { return nil }
        var confirmed = staged
        confirmed.isConfirmed = true
        store.addTransaction(confirmed)
        return confirmed
    }

    /// 「修改 (View)」路径：消费暂存，以未确认状态转入正式记录并定位到 App 内编辑页，
    /// 用户在 App 里改完保存即完成这笔。暂存已被消费但正式记录已存在时（例如重复点击、
    /// 或确认路径已落盘），只重新定位到编辑页，不重复记账。
    @discardableResult
    public static func consumePendingScanForEdit(id: UUID, in store: MimiStore) -> TransactionItem? {
        if let staged = store.consumePendingScan(id: id) {
            store.addTransaction(staged)
            _ = markForInAppModification(transactionId: staged.id, in: store)
            return staged
        }
        if let existing = store.transactions.first(where: { $0.id == id }) {
            _ = markForInAppModification(transactionId: existing.id, in: store)
            return existing
        }
        return nil
    }

    public static func markForInAppModification(transactionId: UUID, in store: MimiStore) -> URL {
        store.pendingEditTransactionId = transactionId
        return URL(string: "mimimoney://edit-bill?id=\(transactionId.uuidString)")!
    }

    public static func handleIncomingURL(_ url: URL, in store: MimiStore) -> Bool {
        guard url.scheme?.lowercased() == "mimimoney" else { return false }
        if url.host == "edit-bill",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
           let uuid = UUID(uuidString: idString) {
            store.pendingEditTransactionId = uuid
            return true
        }
        if url.host == "quick-scan" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let textParam = components?.queryItems?.first(where: { $0.name == "text" })?.value
            let amountParam = components?.queryItems?.first(where: { $0.name == "amount" })?.value
            let noteParam = components?.queryItems?.first(where: { $0.name == "note" || $0.name == "merchant" })?.value
            let accountParam = components?.queryItems?.first(where: { $0.name == "account" })?.value

            var draft: ParsedDraftBill?

            if let amtStr = amountParam, let amt = Double(amtStr), amt > 0 {
                let note = noteParam ?? "快捷记账"
                let acc = accountParam ?? "TNGewallet"
                let detected = DefaultCatalog.resolveCategoryIds(from: note, type: .expense)
                draft = ParsedDraftBill(
                    type: .expense,
                    amount: amt,
                    primaryCategoryId: detected.primaryId,
                    subCategoryId: detected.subId,
                    categoryDisplayName: detected.primaryId,
                    accountId: DefaultCatalog.resolveAccountId(from: acc),
                    accountDisplayName: acc,
                    merchantOrNote: note,
                    occurredAt: Date()
                )
            } else if let txt = textParam, !txt.isEmpty {
                draft = ReceiptOCRService.parseReceiptText(txt)
            } else {
                #if canImport(UIKit)
                if let image = UIPasteboard.general.image, let pngData = image.pngData() {
                    draft = ReceiptOCRService.recognizeAndParseImageSync(pngData)
                } else if let clipText = UIPasteboard.general.string, !clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draft = ReceiptOCRService.parseReceiptText(clipText)
                }
                #endif
            }

            if let recognized = draft {
                let saved = recordRecognizedDraft(recognized, in: store)
                store.pendingShortcutSnippetBill = saved
                return true
            } else {
                store.isRecordSheetPresented = true
                return true
            }
        }
        return false
    }

    public static func openShortcutsApp() {
        #if canImport(UIKit)
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
        #endif
    }

}

// MARK: - Screenshot Result Snippet View (1:1 Match with IMG_2294.PNG)

public struct ScreenshotResultSnippetView: View {
    public let transaction: TransactionItem
    public var onModifyTapped: (() -> Void)?
    public var onConfirmTapped: (() -> Void)?
    public var onCloseTapped: (() -> Void)?

    public init(
        transaction: TransactionItem,
        onModifyTapped: (() -> Void)? = nil,
        onConfirmTapped: (() -> Void)? = nil,
        onCloseTapped: (() -> Void)? = nil
    ) {
        self.transaction = transaction
        self.onModifyTapped = onModifyTapped
        self.onConfirmTapped = onConfirmTapped
        self.onCloseTapped = onCloseTapped
    }

    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: transaction.date)
    }

    private var signedAmountText: String {
        let prefix = transaction.type == .expense ? "-RM" : "+RM"
        return String(format: "%@%.2f", prefix, transaction.amount)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // White recognized bill card inside blue-white gradient popup (IMG_2294 & user feedback)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    MimiStickerIconView(iconName: transaction.iconName, size: 28)

                    Text(transaction.categoryPath)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(MimiTheme.textPrimary)

                    Spacer()

                    Text(signedAmountText)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(
                            transaction.type == .expense ? MimiTheme.expenseBlue : MimiTheme.incomeOrange
                        )

                    if let onClose = onCloseTapped {
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(MimiTheme.textMuted.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 6) {
                    Text(transaction.accountName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(MimiTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color(hex: 0xF2F4F8))
                        )

                    if !transaction.note.isEmpty {
                        Text(transaction.note)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(MimiTheme.textSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color(hex: 0xF2F4F8))
                            )
                    }

                    Spacer()

                    Text(formattedTimestamp)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(MimiTheme.textMuted)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            )

            // Recognition confirmation caption
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(MimiTheme.expenseBlue)
                Text("已识别记录以上信息，打开「咪咪记账」查看更多")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(MimiTheme.textSecondary)
            }

            // Two-Button Action Row: View (修改) & Got it (确认) - matches user screenshot
            #if canImport(AppIntents)
            if #available(iOS 16.0, *) {
                HStack(spacing: 12) {
                    Button(intent: OpenBillForEditIntent(transactionId: transaction.id)) {
                        Text("修改 (View)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MimiTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                Capsule().fill(Color(hex: 0xEDEFF5))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(intent: ConfirmBillIntent(transactionId: transaction.id)) {
                        Text("确认 (Got it)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                Capsule().fill(MimiTheme.expenseBlue)
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                fallbackTwoButtons
            }
            #else
            fallbackTwoButtons
            #endif
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: 0xDEF0FE), Color(hex: 0xF6F9FE)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 6)
    }

    private var fallbackTwoButtons: some View {
        HStack(spacing: 12) {
            Button {
                onModifyTapped?()
            } label: {
                Text("修改 (View)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MimiTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        Capsule().fill(Color(hex: 0xEDEFF5))
                    )
            }
            .buttonStyle(.plain)

            Button {
                onConfirmTapped?()
            } label: {
                Text("确认 (Got it)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        Capsule().fill(MimiTheme.expenseBlue)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Scan Confirmation Card View (确认型呈现专用，v1.1.2)

/// 确认卡卡面：与 ScreenshotResultSnippetView 上半部长相一致（分类图标+分类-二级、
/// 金额、账户 chip、备注 chip、时间、✓ 识别提示一行）。v1.1.3 起卡内不放任何
/// 自制按钮——卡面下方只有系统渲染的一对按钮 View / Got it（requestConfirmation
/// 的 actionName 改名而来，与 Kapi 一致）：Got it = 确认入账，View = 打开 App
/// 改这笔（经 perform 的 catch 分支接成「转未确认记录＋前台打开 App」，见 ScanScreenshotIntent）。
public struct ScanConfirmationCardView: View {
    public let transaction: TransactionItem

    public init(transaction: TransactionItem) {
        self.transaction = transaction
    }

    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: transaction.date)
    }

    private var signedAmountText: String {
        let prefix = transaction.type == .expense ? "-RM" : "+RM"
        return String(format: "%@%.2f", prefix, transaction.amount)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    MimiStickerIconView(iconName: transaction.iconName, size: 28)

                    Text(transaction.categoryPath)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(MimiTheme.textPrimary)

                    Spacer()

                    Text(signedAmountText)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(
                            transaction.type == .expense ? MimiTheme.expenseBlue : MimiTheme.incomeOrange
                        )
                }

                HStack(spacing: 6) {
                    Text(transaction.accountName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(MimiTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color(hex: 0xF2F4F8))
                        )

                    if !transaction.note.isEmpty {
                        Text(transaction.note)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(MimiTheme.textSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color(hex: 0xF2F4F8))
                            )
                    }

                    Spacer()

                    Text(formattedTimestamp)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(MimiTheme.textMuted)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            )

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(MimiTheme.expenseBlue)
                Text("已识别记录以上信息，打开「咪咪记账」查看更多")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(MimiTheme.textSecondary)
            }

            // v1.1.3：卡内不再有任何自制按钮。View / Got it 由系统在卡面
            // 下方成对渲染（见 requestScanConfirmation 的 actionName 改名）。
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: 0xDEF0FE), Color(hex: 0xF6F9FE)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 6)
    }
}

// MARK: - iOS AppIntents Integration (Shortcuts Screenshot Bookkeeping)

#if canImport(AppIntents)
@available(iOS 16.0, macOS 13.0, *)
public struct OpenBillForEditIntent: AppIntent {
    public static var title: LocalizedStringResource = "修改账单 (View)"
    public static var description = IntentDescription("打开咪咪记账并跳转到该笔账单详情编辑页")
    public static var openAppWhenRun: Bool = true
    public static var isDiscoverable: Bool = false

    @Parameter(title: "账单ID")
    public var transactionIdString: String

    public init() {
        self.transactionIdString = ""
    }

    public init(transactionId: UUID) {
        self.transactionIdString = transactionId.uuidString
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: transactionIdString) {
            _ = ShortcutActionCoordinator.markForInAppModification(
                transactionId: uuid,
                in: MimiStore.shared
            )
        }
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct ConfirmBillIntent: AppIntent {
    public static var title: LocalizedStringResource = "确认记账 (Got it)"
    public static var description = IntentDescription("确认截图识别的账单并直接完成记账，无需进入App")
    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = false

    @Parameter(title: "账单ID")
    public var transactionIdString: String

    public init() {
        self.transactionIdString = ""
    }

    public init(transactionId: UUID) {
        self.transactionIdString = transactionId.uuidString
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        MimiStore.shared.pendingShortcutSnippetBill = nil
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct OpenPendingScanForEditIntent: AppIntent {
    public static var title: LocalizedStringResource = "修改待确认账单 (View)"
    public static var description = IntentDescription("把确认卡上的待确认识别账单转入咪咪记账并打开编辑页")
    public static var openAppWhenRun: Bool = true
    public static var isDiscoverable: Bool = false

    @Parameter(title: "账单ID")
    public var transactionIdString: String

    public init() {
        self.transactionIdString = ""
    }

    public init(transactionId: UUID) {
        self.transactionIdString = transactionId.uuidString
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: transactionIdString) {
            _ = ShortcutActionCoordinator.consumePendingScanForEdit(
                id: uuid,
                in: MimiStore.shared
            )
        }
        return .result()
    }
}

/// iOS 26 确认型呈现的卡片驱动 Intent：按账单 id 从暂存区（或已落盘记录）取账单，
/// 渲染 ScanConfirmationCardView。系统在交互后可能重跑本 Intent 刷新卡面，
/// 所以取不到暂存时回退到正式记录，保证卡面不空白。
@available(iOS 26.0, macOS 26.0, *)
public struct ScanConfirmationSnippetIntent: SnippetIntent {
    public static var title: LocalizedStringResource = "确认识别账单"
    public static var description = IntentDescription("展示待确认的识别账单卡片")
    public static var isDiscoverable: Bool = false

    @Parameter(title: "账单ID")
    public var transactionIdString: String

    public init() {
        self.transactionIdString = ""
    }

    public init(transactionId: UUID) {
        self.transactionIdString = transactionId.uuidString
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        let store = MimiStore.shared
        let transaction = UUID(uuidString: transactionIdString).flatMap { id in
            store.pendingScan(id: id) ?? store.transactions.first(where: { $0.id == id })
        }
        if let transaction {
            return .result(view: AnyView(ScanConfirmationCardView(transaction: transaction)))
        }
        return .result(view: AnyView(
            Text("这笔识别结果已处理")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(MimiTheme.textSecondary)
                .padding(16)
        ))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct ScanScreenshotIntent: AppIntent {
    public static var title: LocalizedStringResource = "识别账单"
    public static var description = IntentDescription("识别账单截图并录入金额、商户或转账收款人与扣款账户，弹出确认与修改卡片")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "内容")
    public var content: IntentFile?

    @Parameter(title: "类型", default: 2)
    public var type: Int?

    @Parameter(title: "版本", default: "1.1.3")
    public var version: String?

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        let store = MimiStore.shared
        let draft: ParsedDraftBill
        if let file = content {
            draft = await ReceiptOCRService.recognizeAndParseImageData(file.data)
        } else {
            #if canImport(UIKit)
            if let image = UIPasteboard.general.image, let pngData = image.pngData() {
                draft = await ReceiptOCRService.recognizeAndParseImageData(pngData)
            } else if let clip = UIPasteboard.general.string, !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft = ReceiptOCRService.parseReceiptText(clip)
            } else {
                draft = ReceiptOCRService.parseReceiptText(
                    "-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34"
                )
            }
            #else
            draft = ReceiptOCRService.parseReceiptText(
                "-RM5.90\nPayment - TNGD\nNear Me Voucher Eggette Lab\n08/11/2026 16:56:34"
            )
            #endif
        }
        // 确认型呈现（v1.1.2）：识别结果先暂存（不落盘）→ requestConfirmation 弹确认卡
        // → 用户点确认后才正式落盘 → 返回无可呈现内容的结果。
        // 没有可呈现内容意味着捷徑流程直接结束回原 App，不再出现结果型
        // snippet 底部那个系统 Done 按钮（WWDC25-281：结果型 snippet 底部
        // 唯一按钮就是 Done，确认型没有这个问题）。
        //
        // v1.1.3：卡上只剩系统渲染的一对按钮 View / Got it（actionName 改名）。
        // - 点「Got it」(accept)：requestConfirmation 正常返回 → 正式落盘 →
        //   返回空 .result()，无任何呈现，直接结束回原 App。
        // - 点「View」(deny) 或下滑关卡：系统以取消类错误抛回 perform，两者
        //   无法区分，统一按「去修改」处理——不落正式账，先把暂存消费为
        //   未确认记录并定位编辑页（与 OpenPendingScanForEditIntent 同一逻辑），
        //   再经 ForegroundContinuableIntent 请求系统把 App 带到前台打开。
        //   这推翻了 v1.1.2「取消不 catch」的官方默认指引，是为实现 View
        //   语义刻意为之（用户已知情：下滑也会打开 App）。
        //   实现说明：原本想用 .result(opensIntent:) 打开编辑 Intent，但
        //   IntentResult 的结果类型按目标 Intent 分型——同一 perform 里
        //   .result() 与 opensIntent 结果、以及不同目标的 opensIntent 结果
        //   都无法混用（CI 两次实证编译错误 #OpaqueTypeInference），
        //   故改走前台继续这条路；OpenPendingScanForEditIntent 本身保留，
        //   仍是 App 内/其他入口可复用的「转未确认＋定位编辑页」Intent。
        // - 其他错误：作废暂存，安静收尾，不落盘、不打开 App、不向上抛。
        let staged = ShortcutActionCoordinator.stageRecognizedDraft(draft, in: store)
        do {
            try await requestScanConfirmation(for: staged)
        } catch {
            switch ScanConfirmationFollowUp.followUp(for: error) {
            case .openEditor:
                _ = ShortcutActionCoordinator.consumePendingScanForEdit(id: staged.id, in: store)
                if #available(iOS 17.0, macOS 14.0, *) {
                    // 前台打开失败（系统拒绝/用户取消）也不要抛错：记录已安全
                    // 转为未确认并标记定位，用户手动打开 App 也会直达编辑页。
                    try? await requestToContinueInForeground(
                        IntentDialog("打开「咪咪记账」修改这笔账单")
                    ) { }
                }
                return .result()
            case .discard:
                store.discardPendingScan(id: staged.id)
                return .result()
            }
        }
        _ = ShortcutActionCoordinator.finalizePendingScan(id: staged.id, in: store)
        return .result()
    }

    /// 按系统版本分层弹确认卡，按钮文案统一改名为 View / Got it（与 Kapi 一致）：
    /// iOS 26+ 用 SnippetIntent 驱动的互动确认卡；
    /// iOS 18–25 用带 content 视图的确认（同一套 ConfirmationActionName.custom）；
    /// iOS 17 的旧确认 API 只接受预置文案（.log，对应 Log / Cancel），无法改名，
    /// 功能不变——这是该层的既有限制。
    @MainActor
    private func requestScanConfirmation(for transaction: TransactionItem) async throws {
        if #available(iOS 26.0, macOS 26.0, *) {
            try await requestConfirmation(
                actionName: .custom(acceptLabel: "Got it", acceptAlternatives: [], denyLabel: "View", denyAlternatives: []),
                snippetIntent: ScanConfirmationSnippetIntent(transactionId: transaction.id)
            )
        } else if #available(iOS 18.0, macOS 15.0, *) {
            try await requestConfirmation(
                actionName: .custom(acceptLabel: "Got it", acceptAlternatives: [], denyLabel: "View", denyAlternatives: []),
                dialog: nil, showDialogAsPrompt: false
            ) {
                ScanConfirmationCardView(transaction: transaction)
            }
        } else {
            let amountText = String(
                format: "%@RM%.2f",
                transaction.type == .expense ? "-" : "+",
                transaction.amount
            )
            try await requestConfirmation(
                result: .result(dialog: "确认记账：\(transaction.categoryPath) \(amountText)（\(transaction.accountName)）？"),
                confirmationActionName: .log
            )
        }
    }
}

/// 前台继续能力（v1.1.3）：「识别账单」在确认卡被点「View」/下滑取消后，
/// 靠这个协议请求系统把 App 带到前台打开编辑页。协议本身 iOS 16.4 起可用，
/// 故以带可用性标注的 extension 形式声明一致性，不抬高 Intent 本体的
/// @available(iOS 16.0)（部署目标 17.0，实际运行不受影响）。
@available(iOS 16.4, macOS 13.3, *)
extension ScanScreenshotIntent: ForegroundContinuableIntent {}

@available(iOS 16.0, macOS 13.0, *)
public struct MimiAppShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanScreenshotIntent(),
            phrases: [
                "用\(.applicationName)识别账单",
                "在\(.applicationName)识别账单",
                "用\(.applicationName)截图记账"
            ],
            shortTitle: "识别账单",
            systemImageName: "camera.viewfinder"
        )
    }
}
#else
public struct OpenBillForEditIntent: Sendable {
    public static let openAppWhenRun: Bool = true
    public let transactionIdString: String
    public init(transactionId: UUID) { self.transactionIdString = transactionId.uuidString }
}
public struct ConfirmBillIntent: Sendable {
    public static let openAppWhenRun: Bool = false
    public let transactionIdString: String
    public init(transactionId: UUID) { self.transactionIdString = transactionId.uuidString }
}
public struct OpenPendingScanForEditIntent: Sendable {
    public static let openAppWhenRun: Bool = true
    public let transactionIdString: String
    public init(transactionId: UUID) { self.transactionIdString = transactionId.uuidString }
}
public struct ScanScreenshotIntent: Sendable {
    public init() {}
}
public struct MimiAppShortcutsProvider: Sendable {
    public init() {}
}
#endif
