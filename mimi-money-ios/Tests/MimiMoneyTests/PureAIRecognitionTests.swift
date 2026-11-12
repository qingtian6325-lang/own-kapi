import XCTest
@testable import MimiMoneyCore

// v1.2.1：识别改纯 AI。验证 SmartReceiptRecognizer 的新契约——
// 成功只来自 Gemini（测试用 provider 替身喂结构化结果）；
// 失败（没 key / 额度 / 超时）一律抛 ReceiptRecognitionFailure，
// 不产生草稿、不暂存、不落账，失败文案诚实可读。
@MainActor
final class PureAIRecognitionTests: XCTestCase {
    private var originalProvider: (@Sendable (Data, Date) async throws -> ParsedDraftBill)!

    override func setUp() {
        super.setUp()
        originalProvider = SmartReceiptRecognizer.recognitionProvider
    }

    override func tearDown() {
        SmartReceiptRecognizer.recognitionProvider = originalProvider
        super.tearDown()
    }

    private nonisolated static func fixtureDraftForTest(amount: Double) -> ParsedDraftBill {
        GeminiBillDTO(
            type: "expense",
            amount: amount,
            counterparty: "YING LAI RESTAURANT",
            counterpartyKind: "merchant",
            account: "TNGewallet",
            primaryCategory: "餐饮",
            subCategory: "餐厅",
            occurredAt: "2026-11-10 20:07",
            note: ""
        ).toDraftBill(now: Date())
    }

    func testMissingKeyThrowsAndRecordsNothing() async {
        SmartReceiptRecognizer.recognitionProvider = { _, _ in
            throw GeminiError.missingAPIKey
        }
        let store = MimiStore(inMemory: true)
        let txCount = store.transactions.count
        do {
            _ = try await SmartReceiptRecognizer.recognize(imageData: Data([0x89, 0x50, 0x4E, 0x47]))
            XCTFail("没有 key 时识别必须抛错，不许返回草稿")
        } catch let failure as ReceiptRecognitionFailure {
            XCTAssertEqual(failure, .missingAPIKey)
            XCTAssertTrue(failure.dialogText.contains("还没有填"))
            XCTAssertTrue(failure.dialogText.contains("API Key"))
        } catch {
            XCTFail("应抛 ReceiptRecognitionFailure，实际为：\(error)")
        }
        XCTAssertEqual(store.transactions.count, txCount, "失败不许落账")
        XCTAssertEqual(store.pendingScanTransactions.count, 0, "失败不许暂存")
    }

    func testQuotaFailureThrowsFailedWithHonestReason() async {
        SmartReceiptRecognizer.recognitionProvider = { _, _ in
            throw GeminiError.httpStatus(429, "quota exceeded")
        }
        do {
            _ = try await SmartReceiptRecognizer.recognize(imageData: Data([0xFF, 0xD8]))
            XCTFail("额度失败时识别必须抛错")
        } catch let failure as ReceiptRecognitionFailure {
            XCTAssertEqual(failure, .failed(reason: "HTTP 429：免费额度已用完或请求过于频繁"))
            XCTAssertTrue(failure.dialogText.contains("检查网络"))
            XCTAssertTrue(failure.dialogText.contains("额度"))
        } catch {
            XCTFail("应抛 ReceiptRecognitionFailure，实际为：\(error)")
        }
    }

    func testTimeoutMapsToFriendlyReason() async {
        SmartReceiptRecognizer.recognitionProvider = { _, _ in
            throw URLError(.timedOut)
        }
        do {
            _ = try await SmartReceiptRecognizer.recognize(imageData: Data([0xFF, 0xD8]))
            XCTFail("超时时识别必须抛错")
        } catch let failure as ReceiptRecognitionFailure {
            XCTAssertEqual(failure, .failed(reason: "请求超时（30 秒）"))
        } catch {
            XCTFail("应抛 ReceiptRecognitionFailure，实际为：\(error)")
        }
    }

    func testSuccessReturnsGeminiDraft() async throws {
        SmartReceiptRecognizer.recognitionProvider = { _, _ in
            Self.fixtureDraftForTest(amount: 38.99)
        }
        let result = try await SmartReceiptRecognizer.recognize(imageData: Data([0x89, 0x50]))
        XCTAssertEqual(result.draft.amount, 38.99, accuracy: 0.001)
        XCTAssertEqual(result.draft.merchantOrNote, "YING LAI RESTAURANT 消费")
        XCTAssertFalse(result.isSuspiciousAmount)
    }

    func testSuccessStillFlagsSuspiciousAmount() async throws {
        SmartReceiptRecognizer.recognitionProvider = { _, _ in
            Self.fixtureDraftForTest(amount: 200_000)
        }
        let result = try await SmartReceiptRecognizer.recognize(imageData: Data([0x89, 0x50]))
        XCTAssertTrue(result.isSuspiciousAmount, "金额合理性拦截必须保留")
    }

    func testFailureDialogTexts() {
        XCTAssertTrue(ReceiptRecognitionFailure.noImage.dialogText.contains("没有收到截图"))
        XCTAssertTrue(ReceiptRecognitionFailure.missingAPIKey.dialogText.contains("设置 → AI 识别引擎"))
        let generic = ReceiptRecognitionFailure.failed(reason: "网络请求失败")
        XCTAssertTrue(generic.dialogText.hasPrefix("AI 识别没成功"))
        XCTAssertTrue(generic.statusText.hasPrefix("AI 识别失败"))
    }
}
