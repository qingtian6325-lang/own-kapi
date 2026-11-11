import Foundation

// MARK: - 智能识别门面：Gemini 优先，静默回退本地 Vision OCR
//
// 主路径：填了 Gemini API Key 时先走 Gemini 单引擎识别。
// 以下情况一律静默退回现有本地 OCR（不弹错、不丢账）：没填 key、无网络、
// 超时（8 秒）、HTTP 错误/额度错误、返回无法解析。
// 同时做金额合理性检查：可疑金额由调用方只进未确认/待确认口径。

public enum SmartReceiptRecognizer {
    public struct Result: Sendable {
        public let draft: ParsedDraftBill
        public let usedGemini: Bool
        public let isSuspiciousAmount: Bool

        public init(draft: ParsedDraftBill, usedGemini: Bool, isSuspiciousAmount: Bool) {
            self.draft = draft
            self.usedGemini = usedGemini
            self.isSuspiciousAmount = isSuspiciousAmount
        }
    }

    public static func recognize(imageData: Data, now: Date = Date()) async -> Result {
        if GeminiSettings.hasAPIKey {
            do {
                let draft = try await GeminiClient.recognizeBill(imageData: imageData, now: now)
                GeminiSettings.recordCallStatus(success: true, message: "截图识别成功（Gemini）")
                return Result(
                    draft: draft,
                    usedGemini: true,
                    isSuspiciousAmount: BillAmountSanity.isSuspicious(amount: draft.amount)
                )
            } catch {
                let reason = (error as? GeminiError)?.description ?? error.localizedDescription
                GeminiSettings.recordCallStatus(success: false, message: "识别回退本地 OCR：\(reason)")
                // 静默回退：继续走本地 OCR
            }
        }
        let draft = await ReceiptOCRService.recognizeAndParseImageData(imageData, now: now)
        return Result(
            draft: draft,
            usedGemini: false,
            isSuspiciousAmount: BillAmountSanity.isSuspicious(amount: draft.amount)
        )
    }
}
