import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 上传前图片压缩（识别路径统一入口）
//
// 快捷指令剪贴板 PNG / 相册原图直接 base64 进 Gemini 容易超时与烧额度。
// 统一缩到最长边 maxDimension、jpeg ~0.7，超过 maxUploadBytes 再降质。

public enum GeminiImagePreprocessor {
    /// 用 Double 而不是 CGFloat：macOS host `swift test` 只 import Foundation 时
    /// 没有 UIKit/CoreGraphics，CGFloat 会直接编译失败（同类于 v1.2.0 的编译期挂 CI）。
    public static let maxDimension: Double = 1280
    public static let maxUploadBytes = 1_200_000
    public static let initialJPEGQuality: Double = 0.72

    public static func prepareForUpload(_ data: Data) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        let resized = resizeIfNeeded(image)
        var quality = CGFloat(initialJPEGQuality)
        var output = resized.jpegData(compressionQuality: quality) ?? data
        while output.count > maxUploadBytes, quality > 0.35 {
            quality -= 0.12
            if let next = resized.jpegData(compressionQuality: quality) {
                output = next
            } else {
                break
            }
        }
        return output
        #else
        return data
        #endif
    }

    #if canImport(UIKit)
    private static func resizeIfNeeded(_ image: UIImage) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        let limit = CGFloat(maxDimension)
        guard longest > limit, longest > 0 else { return image }
        let scale = limit / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    #endif
}

// MARK: - 智能识别门面：纯 Gemini 单引擎（v1.2.1 起彻底移除本地 OCR）
//
// 识别只走 Gemini，没有任何 OCR 兜底。失败（没填 key、无网络、超时 30 秒、
// HTTP/额度错误、返回无法解析）一律抛 ReceiptRecognitionFailure：不暂存、
// 不落账、不生成草稿，由调用方把失败原因如实告诉用户。
// 金额合理性检查保持不变：可疑金额由调用方只进未确认/待确认口径。

public enum ReceiptRecognitionFailure: Error, Equatable, Sendable {
    case missingAPIKey
    case noImage
    case failed(reason: String)

    public init(geminiError: GeminiError) {
        switch geminiError {
        case .missingAPIKey:
            self = .missingAPIKey
        default:
            self = .failed(reason: geminiError.description)
        }
    }

    /// 给用户看的失败说明（Intent 弹窗与 App 内提示共用同一套文案）。
    public var dialogText: String {
        switch self {
        case .missingAPIKey:
            return "AI 识别没成功：还没有填 Gemini API Key。请到「咪咪记账 → 设置 → AI 识别引擎」填入 Key 后再试。"
        case .noImage:
            return "AI 识别没成功：没有收到截图。请先截屏付款页面再运行，或把截图复制到剪贴板后再试。"
        case .failed(let reason):
            return "AI 识别没成功：\(reason)。请检查网络，或到「设置 → AI 识别引擎」确认 Key 后再试。"
        }
    }

    /// 记录到设置页「最近一次调用状态」的简述。
    public var statusText: String {
        switch self {
        case .missingAPIKey:
            return "AI 识别失败：尚未填写 Gemini API Key"
        case .noImage:
            return "AI 识别失败：没有收到截图"
        case .failed(let reason):
            return "AI 识别失败：\(reason)"
        }
    }
}

extension ReceiptRecognitionFailure: LocalizedError {
    public var errorDescription: String? { dialogText }
}

public enum SmartReceiptRecognizer {
    public struct Result: Sendable {
        public let draft: ParsedDraftBill
        public let isSuspiciousAmount: Bool

        public init(draft: ParsedDraftBill, isSuspiciousAmount: Bool) {
            self.draft = draft
            self.isSuspiciousAmount = isSuspiciousAmount
        }
    }

    /// 识别执行体（默认直连 GeminiClient）；单元测试可替换以离线验证成功/失败路径。
    static var recognitionProvider: @Sendable (Data, Date) async throws -> ParsedDraftBill = { imageData, now in
        try await GeminiClient.recognizeBill(imageData: imageData, now: now)
    }

    public static func recognize(imageData: Data, now: Date = Date()) async throws -> Result {
        let prepared = GeminiImagePreprocessor.prepareForUpload(imageData)
        do {
            var draft = try await recognitionProvider(prepared, now)
            // 保留压缩后的图，便于确认入账时附上小票（调用方可再覆盖）
            if draft.rawImageData == nil {
                draft.rawImageData = prepared
            }
            GeminiSettings.recordCallStatus(success: true, message: "截图识别成功（Gemini）")
            return Result(
                draft: draft,
                isSuspiciousAmount: BillAmountSanity.isSuspicious(draft: draft)
            )
        } catch let error as GeminiError {
            let failure = ReceiptRecognitionFailure(geminiError: error)
            GeminiSettings.recordCallStatus(success: false, message: failure.statusText)
            throw failure
        } catch {
            let reason: String
            if let urlError = error as? URLError, urlError.code == .timedOut {
                reason = "请求超时（\(Int(GeminiClient.recognitionTimeoutSeconds)) 秒）"
            } else {
                reason = error.localizedDescription
            }
            let failure = ReceiptRecognitionFailure.failed(reason: reason)
            GeminiSettings.recordCallStatus(success: false, message: failure.statusText)
            throw failure
        }
    }
}
