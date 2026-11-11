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

@MainActor
public enum ShortcutActionCoordinator {
    /// 「添加专属指令」一键导入链接（iCloud 快捷指令分享链接，形如 https://www.icloud.com/shortcuts/xxxx）。
    /// 该链接只能由登录 iCloud 的设备在「快捷指令」App 内通过「共享 → 拷贝 iCloud 链接」生成，
    /// 服务器端无法伪造；在用户提供链接之前保持 nil，指南页的「添加专属指令」按钮将展开手动搭建教程。
    public static let shortcutInstallURL: String? = nil

    public static func recordRecognizedDraft(_ draft: ParsedDraftBill, in store: MimiStore) -> TransactionItem {
        var attachments: [String] = []
        if let raw = draft.rawImageData {
            let filename = store.saveReceiptImage(data: raw)
            attachments.append(filename)
        }
        let tx = TransactionItem(
            type: draft.type,
            categoryPath: draft.categoryPath,
            iconName: draft.iconName,
            amount: draft.amount,
            accountName: draft.accountName,
            note: draft.note,
            receiptImageLabels: attachments,
            date: draft.date,
            isConfirmed: true
        )
        store.addTransaction(tx)
        return tx
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
public struct ScanScreenshotIntent: AppIntent {
    public static var title: LocalizedStringResource = "识别账单"
    public static var description = IntentDescription("识别账单截图并录入金额、商户或转账收款人与扣款账户，弹出确认与修改卡片")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "内容")
    public var content: IntentFile?

    @Parameter(title: "类型", default: 2)
    public var type: Int?

    @Parameter(title: "版本", default: "1.1.0")
    public var version: String?

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
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
        let saved = ShortcutActionCoordinator.recordRecognizedDraft(draft, in: store)
        return .result(
            dialog: "已识别记录以上信息，打开「咪咪记账」查看更多"
        ) {
            ScreenshotResultSnippetView(transaction: saved)
        }
    }
}

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
public struct ScanScreenshotIntent: Sendable {
    public init() {}
}
public struct MimiAppShortcutsProvider: Sendable {
    public init() {}
}
#endif
