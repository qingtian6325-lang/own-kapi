import Foundation
#if canImport(Vision)
import Vision
#endif
#if canImport(UIKit)
import UIKit
#endif

public struct ParsedDraftBill: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var type: TransactionType
    public var amount: Double
    public var currency: CurrencyCode
    public var primaryCategoryId: String
    public var subCategoryId: String?
    public var categoryDisplayName: String
    public var accountId: String?
    public var accountDisplayName: String
    public var merchantOrNote: String
    public var occurredAt: Date
    public var rawImageData: Data?

    public var categoryPath: String { categoryDisplayName }
    public var iconName: String {
        DefaultCatalog.resolveCategoryDisplay(
            primaryId: primaryCategoryId,
            subId: subCategoryId,
            type: type
        ).iconName
    }
    public var accountName: String { accountDisplayName }
    public var note: String { merchantOrNote }
    public var date: Date { occurredAt }

    public init(
        id: UUID = UUID(),
        type: TransactionType = .expense,
        amount: Double,
        currency: CurrencyCode = .myr,
        primaryCategoryId: String,
        subCategoryId: String? = nil,
        categoryDisplayName: String,
        accountId: String? = nil,
        accountDisplayName: String,
        merchantOrNote: String,
        occurredAt: Date = Date(),
        rawImageData: Data? = nil
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.currency = currency
        self.primaryCategoryId = primaryCategoryId
        self.subCategoryId = subCategoryId
        self.categoryDisplayName = categoryDisplayName
        self.accountId = accountId
        self.accountDisplayName = accountDisplayName
        self.merchantOrNote = merchantOrNote
        self.occurredAt = occurredAt
        self.rawImageData = rawImageData
    }
}

public final class ReceiptOCRService: Sendable {
    public init() {}

    /// Parses raw OCR text from TNG eWallet (`IMG_2294`), PBBank, CIMB, WeChat/Alipay, or general store receipts.
    /// Explicitly strips long reference numbers (12+ digits) and timestamps before extracting currency amounts.
    public static func parseReceiptText(_ rawText: String, now: Date = Date()) -> ParsedDraftBill {
        let lines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Remove long reference strings (10+ alphanumeric digits with numbers) and date/time patterns when scanning for amounts
        let sanitizedForAmount = lines
            .filter { line in
                let lower = line.lowercased()
                return !lower.contains("wallet ref")
                    && !lower.contains("transaction no")
                    && !lower.contains("reference")
                    && !lower.contains("date/time")
            }
            .joined(separator: "\n")

        let amount = extractPrimaryAmount(from: sanitizedForAmount) ?? extractPrimaryAmount(from: rawText) ?? 0.0
        let (accountId, accountName) = detectAccount(from: rawText)
        let merchantOrRecipient = detectRecipientOrMerchant(from: lines, rawText: rawText)
        let parsedDate = detectTimestamp(from: rawText) ?? now
        let isIncome = detectIsIncome(lines: lines, rawText: rawText)

        let primaryId: String
        let subId: String?
        let categoryDisplay: String
        if isIncome {
            let lowerAll = rawText.lowercased()
            if lowerAll.contains("refund") || lowerAll.contains("退款") || lowerAll.contains("cashback") || lowerAll.contains("返现") {
                (primaryId, subId, categoryDisplay) = ("inc_refund", nil, "退款返还")
            } else {
                (primaryId, subId, categoryDisplay) = ("inc_custom_transfer", nil, "别人转账")
            }
        } else {
            // Classify by the merchant / purpose first (precise), then fall back to the whole
            // screen text (which contains lots of app chrome noise).
            (primaryId, subId, categoryDisplay) = detectCategory(focused: merchantOrRecipient, fullText: rawText)
        }

        return ParsedDraftBill(
            type: isIncome ? .income : .expense,
            amount: amount,
            currency: .myr,
            primaryCategoryId: primaryId,
            subCategoryId: subId,
            categoryDisplayName: categoryDisplay,
            accountId: accountId,
            accountDisplayName: accountName,
            merchantOrNote: merchantOrRecipient,
            occurredAt: parsedDate
        )
    }

    /// Income screens: amount shown with "+RM", or "Received from"/"Receive Money"/"收款" labels.
    private static func detectIsIncome(lines: [String], rawText: String) -> Bool {
        for line in lines {
            let compact = line.replacingOccurrences(of: " ", with: "").lowercased()
            if compact.hasPrefix("+rm") || compact.hasPrefix("+myr") { return true }
            if compact.hasPrefix("-rm") || compact.hasPrefix("-myr") { return false }
        }
        let lower = rawText.lowercased()
        return lower.contains("received from") || lower.contains("receive from") || lower.contains("receive money") || lower.contains("money received") || lower.contains("已收款") || lower.contains("收到转账")
    }

    /// Returns a dummy draft only on non-iOS hosts (unit tests); on device an unreadable
    /// image yields an empty draft (amount 0) instead of a fake bill.
    private static func unreadableImageDraft(_ data: Data, now: Date) -> ParsedDraftBill {
        #if canImport(UIKit)
        return ParsedDraftBill(
            type: .expense,
            amount: 0,
            primaryCategoryId: "exp_other",
            categoryDisplayName: "其他支出",
            accountId: nil,
            accountDisplayName: "TNGewallet",
            merchantOrNote: "",
            occurredAt: now,
            rawImageData: data
        )
        #else
        var fallback = parseReceiptText("-RM5.90\nNear Me Voucher Eggette Lab\nPayment - TNGD\n08/11/2026 16:56:34", now: now)
        fallback.rawImageData = data
        return fallback
        #endif
    }

    public static func recognizeAndParseImageData(_ data: Data, now: Date = Date()) async -> ParsedDraftBill {
        let text = await Task.detached(priority: .userInitiated) {
            recognizeText(in: data)
        }.value
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var draft = parseReceiptText(text, now: now)
            draft.rawImageData = data
            return draft
        }
        return unreadableImageDraft(data, now: now)
    }

    public static func recognizeAndParseImageSync(_ data: Data, now: Date = Date()) -> ParsedDraftBill {
        let text = recognizeText(in: data)
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var draft = parseReceiptText(text, now: now)
            draft.rawImageData = data
            return draft
        }
        return unreadableImageDraft(data, now: now)
    }

    /// Runs Apple Vision OCR synchronously and rebuilds visual rows, so that two-column
    /// receipts ("Date/Time      10/11/2026 12:13:53") become a single "label value" line.
    public static func recognizeText(in data: Data) -> String {
        #if canImport(Vision) && canImport(UIKit)
        guard let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // NOTE: only use languages Vision supports; an unsupported code (e.g. "ms-MY")
        // makes the whole request fail and returns no text at all.
        request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation(uiImage.imageOrientation), options: [:])
        do {
            try handler.perform([request])
        } catch {
            // Retry with English only in case the language set is rejected on this OS.
            request.recognitionLanguages = ["en-US"]
            try? handler.perform([request])
        }
        let observations = request.results ?? []
        return buildRows(from: observations.compactMap { obs -> (CGRect, String)? in
            guard let s = obs.topCandidates(1).first?.string else { return nil }
            return (obs.boundingBox, s)
        })
        #else
        return ""
        #endif
    }

    /// Groups OCR fragments into visual rows (top→bottom, left→right).
    static func buildRows(from items: [(CGRect, String)]) -> String {
        guard !items.isEmpty else { return "" }
        // Vision uses normalized coordinates with origin at bottom-left.
        let sorted = items.sorted { $0.0.midY > $1.0.midY }
        var rows: [[(CGRect, String)]] = []
        for item in sorted {
            if var last = rows.last, let ref = last.first {
                let tolerance = max(ref.0.height, item.0.height) * 0.6
                if abs(ref.0.midY - item.0.midY) <= tolerance {
                    last.append(item)
                    rows[rows.count - 1] = last
                    continue
                }
            }
            rows.append([item])
        }
        return rows
            .map { row in row.sorted { $0.0.minX < $1.0.minX }.map { $0.1 }.joined(separator: "  ") }
            .joined(separator: "\n")
    }

    #if canImport(UIKit)
    private static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
    #endif

    private static func extractPrimaryAmount(from text: String) -> Double? {
        // 1. Prefer explicit currency prefix: RM5.90, -RM38.78, MYR 11.60, ¥150.00
        let currencyPattern = #"(?:RM|MYR|¥|\$)\s*([0-9]{1,6}(?:\.[0-9]{1,2})?)"#
        if let regex = try? NSRegularExpression(pattern: currencyPattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: nsRange),
               let valRange = Range(match.range(at: 1), in: text),
               let val = Double(text[valRange]), val > 0 {
                return val
            }
        }

        // 2. Fallback to decimal numbers with 1-2 decimal places not adjacent to slashes/colons
        let decimalPattern = #"(?<![0-9/:])([0-9]{1,5}\.[0-9]{1,2})(?![0-9/:])"#
        if let regex = try? NSRegularExpression(pattern: decimalPattern) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: nsRange),
               let valRange = Range(match.range(at: 1), in: text),
               let val = Double(text[valRange]), val > 0 {
                return val
            }
        }
        return nil
    }

    private static func detectAccount(from text: String) -> (String?, String) {
        let lower = text.lowercased()
        if lower.contains("pbb") || lower.contains("public bank") || lower.contains("大众银行") {
            return ("acc_pbb", "PBBank")
        }
        if lower.contains("cimb") || lower.contains("联昌") {
            return ("acc_cimb", "CIMB")
        }
        if lower.contains("maybank") || lower.contains("mae") || lower.contains("m2u") {
            return ("acc_maybank", "Maybank")
        }
        if lower.contains("tng") || lower.contains("ewallet") || lower.contains("touch 'n go") || lower.contains("touch n go") || lower.contains("tngd") {
            return ("acc_tng", "TNGewallet")
        }
        if lower.contains("现金") || lower.contains("cash") {
            return ("acc_cash", "现金")
        }
        if lower.contains("duitnow") {
            return ("acc_tng", "TNGewallet")
        }
        return ("acc_tng", "TNGewallet")
    }

    private static func detectCategory(from text: String) -> (String, String?, String) {
        let lower = text.lowercased()

        // 1. Food & Dining (exp_food)
        // 1a. Coffee
        if lower.contains("starbucks") || lower.contains("zus") || lower.contains("gigi coffee") || lower.contains("kenangan") || lower.contains("coffee bean") || lower.contains("咖啡") || lower.contains("latte") || lower.contains("cappuccino") || lower.contains("espresso") || lower.contains("americano") || (lower.contains("coffee") && !lower.contains("shop")) {
            return ("exp_food", "exp_food_coffee", "餐饮-咖啡")
        }
        // 1b. Drinks & Tea
        if lower.contains("beverage") || lower.contains("teh") || lower.contains("奶茶") || lower.contains("饮品") || lower.contains("茶") || lower.contains("tealive") || lower.contains("chagee") || lower.contains("霸王茶姬") || lower.contains("the alley") || lower.contains("koi") || lower.contains("mixue") || lower.contains("蜜雪冰城") || lower.contains("chatime") || lower.contains("boost juice") || lower.contains("heytea") || lower.contains("喜茶") || lower.contains("gong cha") || lower.contains("果汁") || lower.contains("boba") || lower.contains("kopi") {
            return ("exp_food", "exp_food_drink", "餐饮-饮品")
        }
        // 1c. Snacks, Desserts & Bakery
        if lower.contains("eggette") || lower.contains("egg") || lower.contains("voucher") || lower.contains("甜品") || lower.contains("零食") || lower.contains("糖水") || lower.contains("snack") || lower.contains("familymart") || lower.contains("family mart") || lower.contains("全家") || lower.contains("inside scoop") || lower.contains("llaollao") || lower.contains("baskin robbins") || lower.contains("chateraise") || lower.contains("rotiboy") || lower.contains("breadtalk") || lower.contains("lavender") || lower.contains("bakery") || lower.contains("面包") || lower.contains("蛋糕") || lower.contains("冰淇淋") || lower.contains("ice cream") || lower.contains("waffle") || lower.contains("dessert") || lower.contains("cookie") {
            return ("exp_food", "exp_food_snack", "餐饮-零食甜品")
        }
        // 1d. Fresh Groceries & Ingredients
        if lower.contains("jaya grocer") || lower.contains("village grocer") || lower.contains("lotus") || lower.contains("nsk") || lower.contains("giant") || lower.contains("econsave") || lower.contains("aeon big") || lower.contains("pasar") || lower.contains("wet market") || lower.contains("菜市") || lower.contains("菜场") || lower.contains("生鲜") || lower.contains("买菜") || lower.contains("食材") || lower.contains("水果") || lower.contains("蔬菜") || lower.contains("猪肉") || lower.contains("海鲜") {
            return ("exp_food", "exp_food_ingredient", "餐饮-做饭食材")
        }
        // 1e. Takeout & Delivery
        if lower.contains("grabfood") || lower.contains("foodpanda") || lower.contains("shopeefood") || lower.contains("外卖") || lower.contains("打包") || lower.contains("外带") || lower.contains("takeaway") {
            return ("exp_food", "exp_food_takeout", "餐饮-外卖外带")
        }
        // 1f. Restaurants, Hawkers & Fast Food
        if lower.contains("restoran") || lower.contains("restaurant") || lower.contains("rice") || lower.contains("火锅") || lower.contains("餐厅") || lower.contains("午饭") || lower.contains("午餐") || lower.contains("早饭") || lower.contains("早餐") || lower.contains("晚饭") || lower.contains("晚餐") || lower.contains("宵夜") || lower.contains("夜宵") || lower.contains("mcdonald") || lower.contains("kfc") || lower.contains("subway") || lower.contains("texas chicken") || lower.contains("pizza hut") || lower.contains("domino") || lower.contains("sushi") || lower.contains("nando") || lower.contains("din tai fung") || lower.contains("鼎泰丰") || lower.contains("haidilao") || lower.contains("海底捞") || lower.contains("suki-ya") || lower.contains("bbq") || lower.contains("buffet") || lower.contains("kopitiam") || lower.contains("mamak") || lower.contains("hawker") || lower.contains("food court") || lower.contains("茶餐室") || lower.contains("鸡饭") || lower.contains("杂菜饭") || lower.contains("板面") || lower.contains("肉骨茶") || lower.contains("点心") || lower.contains("苦瓜汤") || lower.contains("dining") || lower.contains("lunch") || lower.contains("dinner") {
            return ("exp_food", "exp_food_restaurant", "餐饮-餐厅")
        }

        // 2. Transport (exp_transport)
        // 2a. Fuel & EV Charging
        if lower.contains("shell") || lower.contains("petronas") || lower.contains("caltex") || lower.contains("bhp") || lower.contains("petron") || lower.contains("setel") || lower.contains("gentari") || lower.contains("jomcharge") || lower.contains("打油") || lower.contains("加油") || lower.contains("充电") || lower.contains("petrol") || lower.contains("fuel") || lower.contains("ron95") || lower.contains("ron97") {
            return ("exp_transport", "exp_trans_fuel", "交通-加油充电")
        }
        // 2b. Toll & Parking
        if lower.contains("rfid") || lower.contains("plus toll") || lower.contains("toll") || lower.contains("smarttag") || lower.contains("parking") || lower.contains("jomparking") || lower.contains("flexi parking") || lower.contains("过路费") || lower.contains("停车") || lower.contains("泊车") {
            return ("exp_transport", "exp_trans_parking", "交通-过路停车")
        }
        // 2c. Taxi & Ride Hailing
        if lower.contains("打车") || lower.contains("grab") || lower.contains("滴滴") || lower.contains("taxi") || lower.contains("airasia ride") || lower.contains("maxim") || lower.contains("indrive") || lower.contains("叫车") || lower.contains("德士") {
            return ("exp_transport", "exp_trans_taxi", "交通-打车叫车")
        }
        // 2d. Public Transit
        if lower.contains("rapidkl") || lower.contains("mrt") || lower.contains("lrt") || lower.contains("monorail") || lower.contains("ktm") || lower.contains("地铁") || lower.contains("轻快铁") || lower.contains("巴士") || lower.contains("公交") {
            return ("exp_transport", "exp_trans_public", "交通-公共交通")
        }
        // 2e. Car Care
        if lower.contains("car wash") || lower.contains("car service") || lower.contains("tyre") || lower.contains("洗车") || lower.contains("保养") || lower.contains("修车") || lower.contains("换黑油") || lower.contains("汽车维修") {
            return ("exp_transport", "exp_trans_carcare", "交通-养车")
        }

        // 3. Shopping (exp_shopping)
        // 3a. Daily Necessities & Convenience
        if lower.contains("mr diy") || lower.contains("mrdiy") || lower.contains("eco shop") || lower.contains("daiso") || lower.contains("miniso") || lower.contains("don don donki") || lower.contains("ikea") || lower.contains("99 speedmart") || lower.contains("speedmart") || lower.contains("7-eleven") || lower.contains("kk super mart") || lower.contains("kk mart") || lower.contains("生活用品") || lower.contains("日用品") || lower.contains("纸巾") || lower.contains("洗衣液") {
            return ("exp_shopping", "exp_shop_daily", "购物-生活用品")
        }
        // 3b. Beauty & Pharmacy
        if lower.contains("sephora") || lower.contains("watsons") || lower.contains("watson") || lower.contains("guardian") || lower.contains("屈臣氏") || lower.contains("美妆") || lower.contains("护肤") || lower.contains("面膜") || lower.contains("口红") || lower.contains("化妆品") || lower.contains("skincare") {
            return ("exp_shopping", "exp_shop_beauty", "购物-美妆护肤")
        }
        // 3c. Clothes & Fashion
        if lower.contains("uniqlo") || lower.contains("zara") || lower.contains("h&m") || lower.contains("padini") || lower.contains("cotton on") || lower.contains("nike") || lower.contains("adidas") || lower.contains("puma") || lower.contains("clothes") || lower.contains("shoes") || lower.contains("服饰") || lower.contains("衣服") || lower.contains("鞋子") || lower.contains("包包") {
            return ("exp_shopping", "exp_shop_clothes", "购物-服饰鞋包")
        }
        // 3d. Digital & Electronics
        if lower.contains("apple") || lower.contains("switch") || lower.contains("machines") || lower.contains("harvey norman") || lower.contains("senheng") || lower.contains("xiaomi") || lower.contains("samsung") || lower.contains("dyson") || lower.contains("数码") || lower.contains("电脑") || lower.contains("手机") || lower.contains("耳机") {
            return ("exp_shopping", "exp_shop_digital", "购物-数码电器")
        }
        // 3e. E-Commerce & General Shopping
        if lower.contains("shopee") || lower.contains("lazada") || lower.contains("taobao") || lower.contains("淘宝") || lower.contains("tiktok shop") || lower.contains("网购") || lower.contains("购物") || lower.contains("shopping") {
            return ("exp_shopping", "exp_shop_daily", "购物-生活用品")
        }

        // 4. Housing (exp_housing)
        // 4a. Utilities
        if lower.contains("tnb") || lower.contains("tenaga") || lower.contains("syabas") || lower.contains("air selangor") || lower.contains("saj") || lower.contains("indah water") || lower.contains("水电费") || lower.contains("电费") || lower.contains("水费") {
            return ("exp_housing", "exp_house_utility", "住房-物业水电")
        }
        // 4b. Telecom & Internet
        if lower.contains("unifi") || lower.contains("time internet") || lower.contains("maxis") || lower.contains("hotlink") || lower.contains("celcom") || lower.contains("digi") || lower.contains("u mobile") || lower.contains("yes 5g") || lower.contains("宽带") || lower.contains("话费") || lower.contains("充值") || lower.contains("网费") {
            return ("exp_housing", "exp_house_telecom", "住房-话费网费")
        }
        // 4c. Rent & Loan
        if lower.contains("rent") || lower.contains("rental") || lower.contains("房租") || lower.contains("租金") || lower.contains("房贷") {
            return ("exp_housing", "exp_house_rent", "住房-房租房贷")
        }

        // 5. Entertainment (exp_entertainment)
        // 5a. Digital & Streaming
        if lower.contains("netflix") || lower.contains("spotify") || lower.contains("youtube") || lower.contains("steam") || lower.contains("playstation") || lower.contains("nintendo") || lower.contains("epic games") || lower.contains("genshin") || lower.contains("原神") || lower.contains("王者荣耀") || lower.contains("手游") || lower.contains("会员") || lower.contains("订阅") {
            return ("exp_entertainment", "exp_ent_digital", "休闲娱乐-数字娱乐")
        }
        // 5b. Offline Entertainment
        if lower.contains("麻将") || lower.contains("娱乐") || lower.contains("电影") || lower.contains("gsc") || lower.contains("tgv") || lower.contains("mbo") || lower.contains("cinema") || lower.contains("movie") || lower.contains("ktv") || lower.contains("桌游") || lower.contains("剧本杀") || lower.contains("密室") {
            return ("exp_entertainment", "exp_ent_offline", "休闲娱乐-线下娱乐")
        }

        // 6. Medical (exp_medical)
        if lower.contains("clinic") || lower.contains("klinik") || lower.contains("hospital") || lower.contains("pharmacy") || lower.contains("farmasi") || lower.contains("caring") || lower.contains("big pharmacy") || lower.contains("alpro") || lower.contains("doctor") || lower.contains("诊所") || lower.contains("看病") || lower.contains("买药") || lower.contains("药房") || lower.contains("牙医") {
            return ("exp_medical", "exp_med_doctor", "医疗健康-看病买药")
        }

        // 7. Custom Categories (Home & Car Loan)
        if lower.contains("车贷") || lower.contains("供车") || lower.contains("car loan") {
            return ("exp_custom_carloan", nil, "车贷")
        }
        if lower.contains("家用") || lower.contains("给家用") {
            return ("exp_custom_home", nil, "家用")
        }

        // 8. Transfers / Repayment (exp_transfer_social)
        if lower.contains("还钱") || lower.contains("还款") || lower.contains("借钱") || lower.contains("repay") {
            return ("exp_transfer_social", "exp_social_repay", "资金往来-还款")
        }
        if lower.contains("红包") || lower.contains("礼物") || lower.contains("礼金") || lower.contains("angpao") {
            return ("exp_transfer_social", "exp_social_gift", "资金往来-人情往来")
        }
        if lower.contains("transfer") || lower.contains("转账") || lower.contains("duitnow") {
            return ("exp_daily", "exp_daily_other", "日常支出-转账支出")
        }

        return ("exp_food", "exp_food_restaurant", "餐饮-餐厅")
    }

    /// Extract user transfer description / recipient reference / purpose if present
    private static func detectPaymentPurpose(from lines: [String], rawText: String) -> String? {
        // Match Recipient Reference, Payment Details, Description, Purpose, Remarks, Note, 备注, 附言, 用途
        let purposePattern = #"(?i)(?:recipient\s+reference|payment\s+details|details|description|detail|purpose|remarks|note|备注|用途|附言|说明)[:\s]+([A-Za-z0-9\u4e00-\u9fa5\s\.\-@&]+)"#
        if let regex = try? NSRegularExpression(pattern: purposePattern) {
            let nsRange = NSRange(rawText.startIndex..<rawText.endIndex, in: rawText)
            let matches = regex.matches(in: rawText, range: nsRange)
            for match in matches {
                if let valRange = Range(match.range(at: 1), in: rawText) {
                    let candidate = String(rawText[valRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .newlines).first ?? ""
                    let cleaned = cleanCandidate(candidate)
                    if isValidPurpose(cleaned) {
                        return cleaned
                    }
                }
            }
        }

        // Multi-line: line is "recipient reference" / "payment details" and next line is purpose
        for i in 0..<lines.count {
            let lineLower = lines[i].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if lineLower == "recipient reference" || lineLower == "payment details" || lineLower == "description" || lineLower == "remarks" || lineLower == "备注" || lineLower == "用途" {
                if i + 1 < lines.count {
                    let nextCandidate = cleanCandidate(lines[i + 1])
                    if isValidPurpose(nextCandidate) {
                        return nextCandidate
                    }
                }
            }
        }
        return nil
    }

    private static func isValidPurpose(_ str: String) -> Bool {
        guard str.count >= 2 && str.count <= 40 else { return false }
        let lower = str.lowercased()
        if lower.contains("successful") || lower.contains("transaction") || lower.contains("reference id") { return false }
        if lower.hasPrefix("payment -") || lower == "payment" || lower == "transfer" { return false }
        if str.range(of: #"^[0-9A-Za-z]{12,}$"#, options: .regularExpression) != nil { return false }
        return true
    }

    /// Extract transfer counterparty (转账给谁) or merchant name, combining purpose if found.
    private static func detectRecipientOrMerchant(from lines: [String], rawText: String) -> String {
        let purpose = detectPaymentPurpose(from: lines, rawText: rawText)
        let counterparty = extractCounterpartyOnly(from: lines, rawText: rawText)

        if let purpose = purpose, !purpose.isEmpty {
            if let counterparty = counterparty, !counterparty.isEmpty, counterparty != "转账付款", counterparty.lowercased() != purpose.lowercased() {
                return "\(counterparty) (\(purpose))"
            }
            return purpose
        }

        return counterparty ?? "转账付款"
    }

    private static func extractCounterpartyOnly(from lines: [String], rawText: String) -> String? {
        // 1. Direct transfer / recipient labels: "Transfer to: XXX", "Recipient Name: XXX", "To: XXX", "Paid to: XXX"
        let recipientRegexPattern = #"(?i)(?:transfer\s+to|recipient\s+name|recipient|beneficiary\s+name|paid\s+to|duitnow\s+to|to|转账给|收款人|付款给)[:\s]+([A-Za-z0-9\u4e00-\u9fa5\s\.\-@&]+)"#
        if let regex = try? NSRegularExpression(pattern: recipientRegexPattern) {
            let nsRange = NSRange(rawText.startIndex..<rawText.endIndex, in: rawText)
            if let match = regex.firstMatch(in: rawText, range: nsRange),
               let valRange = Range(match.range(at: 1), in: rawText) {
                let candidate = String(rawText[valRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines).first ?? ""
                let cleaned = cleanCandidate(candidate)
                if isValidCounterparty(cleaned) {
                    return cleaned
                }
            }
        }

        // 2. Check if a line itself is a transfer label and the immediate next line is the recipient name
        for i in 0..<lines.count {
            let lineLower = lines[i].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if lineLower == "transfer to" || lineLower == "recipient name" || lineLower == "recipient" || lineLower == "paid to" || lineLower == "to" || lineLower == "收款人" || lineLower == "转账给" {
                if i + 1 < lines.count {
                    let nextCandidate = cleanCandidate(lines[i + 1])
                    if isValidCounterparty(nextCandidate) {
                        return nextCandidate
                    }
                }
            }
        }

        // 3. Fallback: Detect merchant name line, stripping clutter
        let systemJunkPrefixes = [
            "payment details", "payment method", "date/time", "date & time", "wallet ref",
            "reference", "ref no", "transaction no", "transaction status", "successful",
            "payment successful", "completed", "status", "want to earn", "ask your",
            "learn more", "touch 'n go", "tng ewallet", "duitnow transfer", "done", "share",
            "share receipt", "download", "select", "hide control centre", "screenshot",
            "safari", "carrier", "wi-fi", "5g", "4g", "lte"
        ]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            if lower.hasPrefix("-rm") || lower.hasPrefix("rm") || lower.hasPrefix("+rm") || lower.hasPrefix("myr") {
                continue
            }
            if systemJunkPrefixes.contains(where: { lower.hasPrefix($0) || lower == $0 }) {
                continue
            }
            if lower.contains("successful") || lower.contains("reference") || lower.contains("transaction") {
                continue
            }
            // Ignore lines that look purely like battery percentage, clock, or numbers
            if trimmed.range(of: #"^[0-9:\s%./-]+$"#, options: .regularExpression) != nil {
                continue
            }
            if trimmed.count >= 2 && trimmed.count <= 48 {
                let cleaned = cleanCandidate(trimmed)
                if isValidCounterparty(cleaned) {
                    return cleaned
                }
            }
        }

        return nil
    }

    private static func cleanCandidate(_ str: String) -> String {
        var res = str.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":-—_")))
        let lower = res.lowercased()
        if lower.hasPrefix("payment - ") {
            res = String(res.dropFirst(10)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if lower.hasPrefix("payment -") {
            res = String(res.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if lower.hasPrefix("payment : ") {
            res = String(res.dropFirst(10)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if lower.hasPrefix("payment ") {
            res = String(res.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if lower.hasPrefix("transfer to ") {
            res = String(res.dropFirst(12)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if lower.hasPrefix("to ") {
            res = String(res.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if lower.hasPrefix("paid to ") {
            res = String(res.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return res.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":-—_ ")))
    }

    private static func isValidCounterparty(_ str: String) -> Bool {
        guard str.count >= 2 && str.count <= 50 else { return false }
        let lower = str.lowercased()
        if lower.contains("transaction") || lower.contains("successful") || lower.contains("reference") { return false }
        if lower.contains("duitnow transfer") || lower.contains("payment details") || lower.contains("ewallet balance") { return false }
        if str.range(of: #"^[0-9A-Za-z]{12,}$"#, options: .regularExpression) != nil { return false }
        return true
    }

    private static func isValidPurpose(_ str: String) -> Bool {
        guard str.count >= 2 && str.count <= 60 else { return false }
        let lower = str.lowercased()
        if lower.contains("successful") || lower.contains("transaction no") || lower.contains("wallet ref") || lower.contains("reference id") { return false }
        if lower == "payment" || lower == "transfer" || lower == "payment details" || lower == "ewallet balance" { return false }
        if str.range(of: #"^[0-9A-Za-z]{12,}$"#, options: .regularExpression) != nil { return false }
        return true
    }

    private static func detectCategory(focused: String, fullText: String) -> (String, String?, String) {
        let trimmedFocused = focused.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFocused.isEmpty && trimmedFocused != "转账付款" {
            let focusedResult = detectCategory(from: trimmedFocused)
            if focusedResult.0 != "exp_other" {
                return focusedResult
            }
        }
        return detectCategory(from: fullText)
    }

    /// Flexible timestamp parser for Malaysian bank and eWallet receipts.
    private static func detectTimestamp(from text: String) -> Date? {
        let cal = Calendar(identifier: .gregorian)

        // Pattern 1: dd/MM/yyyy HH:mm:ss or dd/MM/yyyy HH:mm
        let slashPattern = #"([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})\s*,?\s*([0-9]{1,2}):([0-9]{2})(?::([0-9]{2}))?\s*(AM|PM)?"#
        if let regex = try? NSRegularExpression(pattern: slashPattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, range: nsRange) {
                let dStr = textSubstring(text, range: match.range(at: 1))
                let mStr = textSubstring(text, range: match.range(at: 2))
                let yStr = textSubstring(text, range: match.range(at: 3))
                let hStr = textSubstring(text, range: match.range(at: 4))
                let minStr = textSubstring(text, range: match.range(at: 5))
                let ampmStr = match.range(at: 7).location != NSNotFound ? textSubstring(text, range: match.range(at: 7)).uppercased() : nil

                var hour = Int(hStr) ?? 0
                if ampmStr == "PM" && hour < 12 { hour += 12 }
                if ampmStr == "AM" && hour == 12 { hour = 0 }

                return cal.date(from: DateComponents(
                    year: Int(yStr),
                    month: Int(mStr),
                    day: Int(dStr),
                    hour: hour,
                    minute: Int(minStr)
                ))
            }
        }

        // Pattern 2: English month like 08 Nov 2026, 09:59 PM or 8 November 2026 16:56
        let monthMap: [String: Int] = [
            "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
            "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
            "january": 1, "february": 2, "march": 3, "april": 4, "june": 6,
            "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12
        ]
        let enPattern = #"([0-9]{1,2})\s+([A-Za-z]{3,9})\s+([0-9]{4}),?\s*([0-9]{1,2}):([0-9]{2})\s*(AM|PM)?"#
        if let regex = try? NSRegularExpression(pattern: enPattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, range: nsRange) {
                let dStr = textSubstring(text, range: match.range(at: 1))
                let mName = textSubstring(text, range: match.range(at: 2)).lowercased()
                let yStr = textSubstring(text, range: match.range(at: 3))
                let hStr = textSubstring(text, range: match.range(at: 4))
                let minStr = textSubstring(text, range: match.range(at: 5))
                let ampmStr = match.range(at: 6).location != NSNotFound ? textSubstring(text, range: match.range(at: 6)).uppercased() : nil

                if let mVal = monthMap[mName] {
                    var hour = Int(hStr) ?? 0
                    if ampmStr == "PM" && hour < 12 { hour += 12 }
                    if ampmStr == "AM" && hour == 12 { hour = 0 }

                    return cal.date(from: DateComponents(
                        year: Int(yStr),
                        month: mVal,
                        day: Int(dStr),
                        hour: hour,
                        minute: Int(minStr)
                    ))
                }
            }
        }

        // Pattern 3: yyyy-MM-dd HH:mm:ss or yyyy/MM/dd HH:mm
        let isoPattern = #"([0-9]{4})[-/]([0-9]{1,2})[-/]([0-9]{1,2})\s+([0-9]{1,2}):([0-9]{2})"#
        if let regex = try? NSRegularExpression(pattern: isoPattern) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, range: nsRange) {
                let yStr = textSubstring(text, range: match.range(at: 1))
                let mStr = textSubstring(text, range: match.range(at: 2))
                let dStr = textSubstring(text, range: match.range(at: 3))
                let hStr = textSubstring(text, range: match.range(at: 4))
                let minStr = textSubstring(text, range: match.range(at: 5))

                return cal.date(from: DateComponents(
                    year: Int(yStr),
                    month: Int(mStr),
                    day: Int(dStr),
                    hour: Int(hStr),
                    minute: Int(minStr)
                ))
            }
        }

        return nil
    }

    private static func textSubstring(_ text: String, range: NSRange) -> String {
        guard let r = Range(range, in: text) else { return "" }
        return String(text[r])
    }
}
