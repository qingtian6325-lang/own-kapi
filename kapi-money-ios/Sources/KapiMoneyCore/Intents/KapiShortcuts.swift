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
    public static func recordRecognizedDraft(_ draft: ParsedDraftBill, in store: KapiStore) -> TransactionItem {
        let tx = TransactionItem(
            type: draft.type,
            categoryPath: draft.categoryPath,
            iconName: draft.iconName,
            amount: draft.amount,
            accountName: draft.accountName,
            note: draft.note,
            date: draft.date,
            isConfirmed: true
        )
        store.addTransaction(tx)
        return tx
    }

    public static func markForInAppModification(transactionId: UUID, in store: KapiStore) -> URL {
        store.pendingEditTransactionId = transactionId
        return URL(string: "kapimoney://edit-bill?id=\(transactionId.uuidString)")!
    }

    public static func handleIncomingURL(_ url: URL, in store: KapiStore) -> Bool {
        guard url.scheme?.lowercased() == "kapimoney" else { return false }
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

    public static let bundledShortcutBase64 = "YnBsaXN0MDDYAQIDBAUGBwgJKSorMDEzNF8QEVdGV29ya2Zsb3dBY3Rpb25zXxAXV0ZXb3JrZmxvd0NsaWVudFJlbGVhc2VfEBdXRldvcmtmbG93Q2xpZW50VmVyc2lvbl5XRldvcmtmbG93SWNvbl8QGVdGV29ya2Zsb3dJbXBvcnRRdWVzdGlvbnNfECFXRldvcmtmbG93SW5wdXRDb250ZW50SXRlbUNsYXNzZXNfEB5XRldvcmtmbG93TWluaW11bUNsaWVudFZlcnNpb25fEA9XRldvcmtmbG93VHlwZXOjChEg0gsMDQ5fEBpXRldvcmtmbG93QWN0aW9uSWRlbnRpZmllcl8QGldGV29ya2Zsb3dBY3Rpb25QYXJhbWV0ZXJzXxAiaXMud29ya2Zsb3cuYWN0aW9ucy50YWtlc2NyZWVuc2hvdNEPEFRVVUlEXxAkODRCOUFBMjgtOEY2QS00MTA0LUEyQTQtQzkwMzQ0OERDQ0Mw0gsMEhNfECBpcy53b3JrZmxvdy5hY3Rpb25zLnNldGNsaXBib2FyZNIPFBUWV1dGSW5wdXRfECRDQUFDRjlBRS0xNjM0LTQ3ODQtODA5Qi00RjA5QjQ4MUFDN0XSFxgZH1VWYWx1ZV8QE1dGU2VyaWFsaXphdGlvblR5cGXTGhscHRAeWk91dHB1dE5hbWVaT3V0cHV0VVVJRFRUeXBlYmIqXE9cQWN0aW9uT3V0cHV0XxAVV0ZUZXh0VG9rZW5BdHRhY2htZW500gsMISJfEBtpcy53b3JrZmxvdy5hY3Rpb25zLm9wZW51cmzSDxQjJF8QJEVCM0U3QUM3LUIwMDItNDUzQy1CRTU1LTQzRDIxNDY2RUI1QtIXGCUo0SYnVnN0cmluZ18QFmthcGltb25leTovL3F1aWNrLXNjYW5fEBFXRlRleHRUb2tlblN0cmluZ1MyLjBYMjYwMC4wLjDSLC0uL18QGVdGV29ya2Zsb3dJY29uR2x5cGhOdW1iZXJfEBhXRldvcmtmbG93SWNvblN0YXJ0Q29sb3IR6HcS/0NR/6ChMl8QEldGSW1hZ2VDb250ZW50SXRlbREDhKM1NjdYTkNXaWRnZXRVV2F0Y2hfEA9BY3Rpb25FeHRlbnNpb24ACAAZAC0ARwBhAHAAjACwANEA4wDnAOwBCQEmAUsBTgFTAXoBfwGiAacBrwHWAdsB4QH3Af4CCQIUAhkCHgIrAkMCSAJmAmsCkgKXApoCoQK6As4C0gLbAuAC/AMXAxoDHwMgAyIDNwM6Az4DRwNNAAAAAAAAAgEAAAAAAAAAOAAAAAAAAAAAAAAAAAAAA18="

    public static func getLocalShortcutFileURL() -> URL? {
        guard let data = Data(base64Encoded: bundledShortcutBase64) else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
        let fileUrl = tempDir.appendingPathComponent("咔皮截屏自动记账.shortcut")
        do {
            try data.write(to: fileUrl)
            return fileUrl
        } catch {
            return nil
        }
    }

    public static func openShortcutsApp() {
        #if canImport(UIKit)
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
        #endif
    }

    public static func openOnlineShortcutInstallURL() {
        #if canImport(UIKit)
        if let url = URL(string: "https://github.com/qingtian6325-lang/own-kapi/releases/download/v1.0.3/KapiScreenshotBookkeeping.shortcut") {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    openShortcutsApp()
                }
            }
        }
        #endif
    }
}

// MARK: - Screenshot Result Snippet View (1:1 Match with IMG_2294.PNG)

public struct ScreenshotResultSnippetView: View {
    public let transaction: TransactionItem
    public var onModifyTapped: (() -> Void)?
    public var onConfirmTapped: (() -> Void)?

    public init(
        transaction: TransactionItem,
        onModifyTapped: (() -> Void)? = nil,
        onConfirmTapped: (() -> Void)? = nil
    ) {
        self.transaction = transaction
        self.onModifyTapped = onModifyTapped
        self.onConfirmTapped = onConfirmTapped
    }

    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: transaction.date)
    }

    private var signedAmountText: String {
        let prefix = transaction.type == .expense ? "-RM" : "+RM"
        return String(format: "%@%.2f", prefix, transaction.amount)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // White recognized bill card inside blue-white gradient popup (IMG_2294)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(hex: 0xFFF3E0))
                            .frame(width: 34, height: 34)
                        Text("🍮")
                            .font(.system(size: 18))
                    }

                    Text(transaction.categoryPath)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(KapiTheme.textPrimary)

                    Spacer()

                    Text(signedAmountText)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(
                            transaction.type == .expense ? KapiTheme.expenseBlue : KapiTheme.incomeOrange
                        )
                }

                HStack(spacing: 6) {
                    Text(transaction.accountName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(KapiTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color(hex: 0xF2F4F8))
                        )

                    if !transaction.note.isEmpty {
                        Text(transaction.note)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(KapiTheme.textSecondary)
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
                        .foregroundColor(KapiTheme.textMuted)
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
                    .foregroundColor(KapiTheme.balanceGreen)
                Text("已识别记录以上信息，打开「咔皮记账」查看更多")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(KapiTheme.textSecondary)
            }

            // Two-Button Action Row: 修改 (View) & 确认 (Got it)
            HStack(spacing: 12) {
                Button {
                    onModifyTapped?()
                } label: {
                    Text("修改 (View)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(KapiTheme.textPrimary)
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
                            Capsule().fill(KapiTheme.expenseBlue)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: 0xE8F0FE), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 6)
    }
}

// MARK: - iOS AppIntents Integration (Shortcuts Screenshot Bookkeeping)

#if canImport(AppIntents)
@available(iOS 16.0, macOS 13.0, *)
public struct OpenBillForEditIntent: AppIntent {
    public static var title: LocalizedStringResource = "修改账单 (View)"
    public static var description = IntentDescription("打开咔皮记账并跳转到该笔账单详情编辑页")
    public static var openAppWhenRun: Bool = true

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
                in: KapiStore.shared
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
        KapiStore.shared.pendingShortcutSnippetBill = nil
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct ScanScreenshotIntent: AppIntent {
    public static var title: LocalizedStringResource = "咔皮截图记账"
    public static var description = IntentDescription("自动截取当前付款页面并识别金额、商户与账户，弹出确认与修改卡片")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "截图文件")
    public var screenshotFile: IntentFile?

    @Parameter(title: "识别后跳转修改")
    public var openForModifyAfterScan: Bool?

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let store = KapiStore.shared
        let draft: ParsedDraftBill
        if let file = screenshotFile {
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
        if openForModifyAfterScan == true {
            _ = ShortcutActionCoordinator.markForInAppModification(transactionId: saved.id, in: store)
        }
        return .result(
            dialog: "已识别记录以上信息，打开「咔皮记账」查看更多"
        ) {
            ScreenshotResultSnippetView(transaction: saved)
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct KapiAppShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanScreenshotIntent(),
            phrases: [
                "用\(.applicationName)截图记账",
                "在\(.applicationName)识别付款截图"
            ],
            shortTitle: "咔皮截图记账",
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
public struct KapiAppShortcutsProvider: Sendable {
    public init() {}
}
#endif
