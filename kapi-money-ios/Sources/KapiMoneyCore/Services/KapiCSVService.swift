import Foundation

public enum KapiCSVService {
    /// Parses Kapi Money's dual-table CSV export format (supporting RFC-4180 multiline quoted fields):
    /// Table 1: 日期,时间,类型,金额,一级分类,二级分类,标签,账户,计入收支,计入预算,所属账本,备注,分摊明细
    /// Table 2: 日期,时间,类型,金额,转入账户,转出账户,备注
    public static func parseKapiCSV(_ csvText: String) -> [TransactionItem] {
        let rows = parseCSVRows(csvText)
        var items: [TransactionItem] = []
        var isTransferSection = false

        let cal = Calendar(identifier: .gregorian)

        for (rowIdx, row) in rows.enumerated() {
            guard !row.isEmpty else { continue }
            let firstCol = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if firstCol.isEmpty { continue }

            // Detect section headers
            if firstCol == "日期" {
                if row.count >= 6 && row[4].contains("转入账户") {
                    isTransferSection = true
                } else {
                    isTransferSection = false
                }
                continue
            }

            guard row.count >= 4 else { continue }
            let dateStr = firstCol
            let timeStr = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let typeStr = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let amountStr = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let amount = Double(amountStr), amount > 0 else { continue }

            let billDate = parseDateTime(dateStr: dateStr, timeStr: timeStr, calendar: cal)
            let deterministicUUID = makeDeterministicUUID(index: rowIdx + 1)

            if isTransferSection || typeStr == "账户互转" || typeStr == "转账" {
                // 日期,时间,类型,金额,转入账户,转出账户,备注
                let toAccountName = row.count > 4 ? row[4].trimmingCharacters(in: .whitespacesAndNewlines) : "TNGewallet"
                let fromAccountName = row.count > 5 ? row[5].trimmingCharacters(in: .whitespacesAndNewlines) : "PBBank"
                let note = row.count > 6 ? row[6].trimmingCharacters(in: .whitespacesAndNewlines) : ""

                let tx = TransactionItem(
                    id: deterministicUUID,
                    ledgerId: "ledger_main",
                    type: .transfer,
                    amount: amount,
                    currency: .myr,
                    primaryCategoryId: "transfer",
                    subCategoryId: nil,
                    accountId: DefaultCatalog.resolveAccountId(from: fromAccountName),
                    targetAccountId: DefaultCatalog.resolveAccountId(from: toAccountName),
                    note: note,
                    includeInStats: false,
                    includeInBudget: false,
                    date: billDate,
                    createdAt: billDate
                )
                items.append(tx)
            } else {
                // 日期,时间,类型,金额,一级分类,二级分类,标签,账户,计入收支,计入预算,所属账本,备注,分摊明细
                let txType: TransactionType = (typeStr == "收入") ? .income : .expense
                let primaryCatName = row.count > 4 ? row[4].trimmingCharacters(in: .whitespacesAndNewlines) : "餐饮"
                let subCatName = row.count > 5 ? row[5].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let tagText = row.count > 6 ? row[6].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let accountName = row.count > 7 ? row[7].trimmingCharacters(in: .whitespacesAndNewlines) : "TNGewallet"
                let includeInStatsStr = row.count > 8 ? row[8].trimmingCharacters(in: .whitespacesAndNewlines) : "是"
                let includeInBudgetStr = row.count > 9 ? row[9].trimmingCharacters(in: .whitespacesAndNewlines) : "是"
                let ledgerName = row.count > 10 ? row[10].trimmingCharacters(in: .whitespacesAndNewlines) : "Main Ledger"
                let note = row.count > 11 ? row[11].trimmingCharacters(in: .whitespacesAndNewlines) : ""

                let catPath = subCatName.isEmpty ? primaryCatName : "\(primaryCatName)-\(subCatName)"
                let resolvedCat = DefaultCatalog.resolveCategoryIds(from: catPath, type: txType)
                let resolvedAcc = DefaultCatalog.resolveAccountId(from: accountName)
                let includeInStats = (includeInStatsStr != "否")
                let includeInBudget = (txType == .expense) ? (includeInBudgetStr != "否") : false
                let tags = tagText.isEmpty ? [] : tagText.components(separatedBy: CharacterSet(charactersIn: ",，;； ")).filter { !$0.isEmpty }

                let tx = TransactionItem(
                    id: deterministicUUID,
                    ledgerId: (ledgerName.isEmpty || ledgerName == "Main Ledger") ? "ledger_main" : ledgerName,
                    type: txType,
                    amount: amount,
                    currency: .myr,
                    primaryCategoryId: resolvedCat.primaryId,
                    subCategoryId: resolvedCat.subId,
                    accountId: resolvedAcc,
                    targetAccountId: nil,
                    note: note,
                    counterparty: "",
                    discountAmount: 0.0,
                    refundAmount: 0.0,
                    includeInStats: includeInStats,
                    includeInBudget: includeInBudget,
                    tags: tags,
                    attachmentPaths: [],
                    date: billDate,
                    createdAt: billDate
                )
                items.append(tx)
            }
        }

        return items.sorted { $0.date > $1.date }
    }

    /// Exports transactions to Kapi Money's dual-table CSV format
    public static func exportKapiCSV(transactions: [TransactionItem]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        var lines: [String] = [
            "日期,时间,类型,金额,一级分类,二级分类,标签,账户,计入收支,计入预算,所属账本,备注,分摊明细"
        ]

        let nonTransfers = transactions.filter { $0.type != .transfer }.sorted { $0.date < $1.date }
        let transfers = transactions.filter { $0.type == .transfer }.sorted { $0.date < $1.date }

        for tx in nonTransfers {
            let d = dateFormatter.string(from: tx.date)
            let t = timeFormatter.string(from: tx.date)
            let parts = tx.categoryPath.components(separatedBy: "-")
            let pCat = parts.first ?? tx.categoryPath
            let sCat = parts.count > 1 ? parts.dropFirst().joined(separator: "-") : ""
            let tags = tx.tags.joined(separator: ";")
            let incStats = tx.includeInStats ? "是" : "否"
            let incBudget = tx.type == .expense ? (tx.includeInBudget ? "是" : "否") : ""
            let noteEscaped = escapeCSVField(tx.note)
            let amtStr = formatCleanNumber(tx.amount)
            lines.append("\(d),\(t),\(tx.type.rawValue),\(amtStr),\(pCat),\(sCat),\(tags),\(tx.accountName),\(incStats),\(incBudget),\(tx.ledgerName),\(noteEscaped),")
        }

        if !transfers.isEmpty {
            lines.append("日期,时间,类型,金额,转入账户,转出账户,备注")
            for tx in transfers {
                let d = dateFormatter.string(from: tx.date)
                let t = timeFormatter.string(from: tx.date)
                let toAcc = DefaultCatalog.resolveAccountName(from: tx.targetAccountId)
                let fromAcc = DefaultCatalog.resolveAccountName(from: tx.accountId)
                let noteEscaped = escapeCSVField(tx.note)
                let amtStr = formatCleanNumber(tx.amount)
                lines.append("\(d),\(t),账户互转,\(amtStr),\(toAcc),\(fromAcc),\(noteEscaped)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func parseCSVRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == "," {
                    currentRow.append(currentField)
                    currentField = ""
                } else if c == "\r" {
                    if i + 1 < chars.count && chars[i + 1] == "\n" {
                        i += 1
                    }
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                } else if c == "\n" {
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                } else {
                    currentField.append(c)
                }
            }
            i += 1
        }
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }
        return rows
    }

    private static func parseDateTime(dateStr: String, timeStr: String, calendar: Calendar) -> Date {
        let dParts = dateStr.split(separator: "-").compactMap { Int($0) }
        let tParts = timeStr.split(separator: ":").compactMap { Int($0) }
        guard dParts.count == 3 else { return Date() }
        let comps = DateComponents(
            year: dParts[0],
            month: dParts[1],
            day: dParts[2],
            hour: tParts.count > 0 ? tParts[0] : 12,
            minute: tParts.count > 1 ? tParts[1] : 0,
            second: tParts.count > 2 ? tParts[2] : 0
        )
        return calendar.date(from: comps) ?? Date()
    }

    private static func makeDeterministicUUID(index: Int) -> UUID {
        let hex = String(format: "%012x", index)
        return UUID(uuidString: "00000000-0000-0000-0000-\(hex)") ?? UUID()
    }

    private static func escapeCSVField(_ value: String) -> String {
        if value.contains(",") || value.contains("\n") || value.contains("\"") {
            let doubled = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        }
        return value
    }

    private static func formatCleanNumber(_ val: Double) -> String {
        if abs(val.rounded() - val) < 0.0001 {
            return String(format: "%.0f", val)
        }
        let twoDec = String(format: "%.2f", val)
        if twoDec.hasSuffix("0") {
            return String(twoDec.dropLast())
        }
        return twoDec
    }

    // MARK: - User's 141 Real Exported Records (2026-09-22 to 2026-11-08)

    public static let userExportedCSV: String = #"""
日期,时间,类型,金额,一级分类,二级分类,标签,账户,计入收支,计入预算,所属账本,备注,分摊明细
2026-09-22,07:16:00,支出,5,交通,加油充电,,TNGewallet,是,是,Main Ledger,PETRON JALAN DANGA NB 消费,
2026-09-22,12:21:00,支出,2,餐饮,,,TNGewallet,是,是,Main Ledger,APEX FOOD SERVICE SDN BHD 消费,
2026-09-22,12:25:04,收入,6.53,个体经营,,,TNGewallet,是,,Main Ledger,,
2026-09-23,13:00:00,支出,14.6,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,今天吃了14.60的午餐用tng付款,
2026-09-24,07:30:00,支出,5,交通,加油充电,,TNGewallet,是,是,Main Ledger,PETRON JALAN DANGA NB (FI) 消费,
2026-09-24,12:42:00,支出,7,餐饮,餐厅,,现金,是,是,Main Ledger,杂菜饭 7,
2026-09-24,12:42:00,支出,0.7,餐饮,饮品,,TNGewallet,是,是,Main Ledger,0.7买了中国茶 用tng,
2026-09-24,12:52:26,收入,10.5,投资收入,股息分红,,PBBank,是,,Main Ledger,,
2026-09-24,20:37:00,支出,31,餐饮,饮品,,TNGewallet,是,是,Main Ledger,CHAGEE（Sutera Mall）香草乌龙奶茶（买1送1）,
2026-09-25,07:23:00,支出,5,交通,加油充电,,TNGewallet,是,是,Main Ledger,PETRON JALAN DANGA NB (FI) 消费,
2026-09-25,15:05:00,支出,13.32,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,今天吃绿园给钱13.32 用tng给的,
2026-09-25,23:42:00,支出,6,资金往来,人情往来,,TNGewallet,是,是,Main Ledger,转账至TEE MIN HAO,
2026-09-26,13:14:00,支出,51.9,餐饮,餐厅,,现金,是,是,Main Ledger,香辣芝士汤部队锅、泡菜煎饼、冰绿茶,
2026-09-26,18:23:00,支出,18.6,餐饮,咖啡,,CIMB,是,是,Main Ledger,转账支付MYR 18.60 给tree in one cafe,
2026-09-26,21:20:00,支出,18.45,餐饮,餐厅,,CIMB,是,是,Main Ledger,SDS BAKERY & CAFETE JOHOR 消费 晚餐,
2026-09-28,12:44:00,支出,0.7,餐饮,饮品,,TNGewallet,是,是,Main Ledger,中国茶转账,
2026-09-28,13:29:00,支出,10,餐饮,餐厅,,现金,是,是,Main Ledger,吃鸡饭用现金还10块,
2026-09-28,16:11:17,收入,2730.63,职业收入,,,PBBank,是,,Main Ledger,,
2026-09-28,16:11:49,支出,500,投资理财,,,PBBank,是,否,Main Ledger,,
2026-09-28,20:07:38,支出,500,家用,,,PBBank,是,是,Main Ledger,给妈妈家用,
2026-09-28,20:10:20,支出,500,家用,,,PBBank,是,是,Main Ledger,给爸爸家用,
2026-09-28,20:12:02,支出,50,购物,,,PBBank,是,是,Main Ledger,还jieying的mooncake,
2026-09-29,13:07:00,支出,37.85,餐饮,,,TNGewallet,是,是,Main Ledger,GRANDMA ONG @ KULAI 消费,
2026-09-29,13:07:00,收入,0.01,退款返还,返现,,TNGewallet,是,,Main Ledger,收到店内现金返还,
2026-09-29,14:03:19,收入,17.9,别人转账,,,PBBank,是,,Main Ledger,,
2026-09-29,18:47:00,支出,30,住房,话费网费,,PBBank,是,是,Main Ledger,电话费30用pbb,
2026-09-30,13:20:00,支出,23.8,餐饮,,,TNGewallet,是,是,Main Ledger,支付予SOH YI YANG的餐费,
2026-09-30,22:42:00,支出,7,餐饮,,,TNGewallet,是,是,Main Ledger,支付TOM YAM餐费,
2026-10-01,12:32:00,支出,8.3,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,YING LAI RESTAURANT 餐飲消費,
2026-10-01,13:06:00,支出,4.5,购物,,,TNGewallet,是,是,Main Ledger,向99 Speedmart支付4.50马币,
2026-10-01,22:20:00,支出,390.5,餐饮,,,PBBank,是,否,Main Ledger,,
2026-10-02,18:33:00,支出,70,交通,加油充电,,TNGewallet,是,是,Main Ledger,PETRON加油支付70令吉,
2026-10-02,18:36:00,收入,17.48,退款返还,,,TNGewallet,是,,Main Ledger,收到PETRON退款17.48马币,
2026-10-02,19:40:00,收入,80,别人转账,,,TNGewallet,是,,Main Ledger,KFC转账,
2026-10-02,21:33:56,支出,75.66,餐饮,餐厅,,PBBank,是,是,Main Ledger,购买KFC套餐及配餐,
2026-10-02,21:36:00,支出,63,餐饮,,,PBBank,是,是,Main Ledger,吃苦瓜汤 ¥63,
2026-10-02,21:36:00,收入,20.8,退款返还,他人还款,,TNGewallet,是,,Main Ledger,同事 ¥20.8,
2026-10-02,21:36:00,收入,22.75,退款返还,他人还款,,TNGewallet,是,,Main Ledger,同事 ¥22.75,
2026-10-02,21:39:00,支出,50,交通,交通卡充值,,TNGewallet,是,是,Main Ledger,我用TNGewallet充Tng卡 用了50块,
2026-10-03,03:30:00,支出,29.9,购物,服饰鞋包,,PBBank,是,是,Main Ledger,今天买uniqlo给jw用pbbank付款花了29.9,
2026-10-03,11:00:00,支出,10.6,餐饮,餐厅,,PBBank,是,是,Main Ledger,今天买文华鸡饭给弟弟吃花了10.9,
2026-10-03,13:22:00,支出,29.65,餐饮,,,TNGewallet,是,是,Main Ledger,支付予Kopi27的消费,
2026-10-03,20:03:00,支出,3.4,购物,,,TNGewallet,是,是,Main Ledger,7-ELEVEN 消费,
2026-10-04,15:45:00,支出,1.9,购物,生活用品,,TNGewallet,是,是,Main Ledger,Best Light Diy Sdn Bhd 消费,
2026-10-04,21:02:00,支出,11,餐饮,,,TNGewallet,是,是,Main Ledger,TT FOOD TRUCK JB2 消费 臭豆腐,
2026-10-04,21:41:00,支出,12.4,购物,,,TNGewallet,是,是,Main Ledger,MOONLIGHT-SUTERA UTAMA 消费,
2026-10-05,12:30:00,支出,9.8,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,YING LAI RESTAURANT 消费 午餐 杂菜饭,
2026-10-06,21:01:00,支出,12,餐饮,,,TNGewallet,是,是,Main Ledger,转账给SOH YI YANG（午餐）,
2026-10-06,21:05:00,支出,16,餐饮,,,TNGewallet,是,是,Main Ledger,餐飲支出 星期留 ayam gepuk,
2026-10-06,21:47:00,支出,7,餐饮,,,TNGewallet,是,是,Main Ledger,Senai mamak milo ais 消费,
2026-10-06,23:32:00,支出,69.37,购物,生活用品,,PBBank,是,是,Main Ledger,Shopee订单消费,
2026-10-07,12:00:00,收入,143.05,职业收入,绩效奖金,,PBBank,是,,Main Ledger,OT钱 9月,
2026-10-07,13:36:00,支出,21.49,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,支付餐费21.49 日式咖喱饭,
2026-10-08,01:37:00,支出,47.56,交通,加油充电,,TNGewallet,是,是,Main Ledger,打油47.56 在10月8号 用tng付款,
2026-10-08,13:08:00,支出,70.9,餐饮,,,TNGewallet,是,是,Main Ledger,GRANDMA ONG @ KULAI 消费,
2026-10-08,13:08:00,收入,3.9,别人转账,,,TNGewallet,是,,Main Ledger,资金转账（来自LEE JING WEN）,
2026-10-08,13:10:00,收入,24,别人转账,,,TNGewallet,是,,Main Ledger,接收来自SOH YI YANG的电子钱包转账,
2026-10-08,13:12:00,收入,20.03,别人转账,,,TNGewallet,是,,Main Ledger,接收来自LIM KAI LUN的电子钱包转账,
2026-10-09,12:38:00,支出,9.8,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,YING LAI RESTAURANT 消费 杂菜饭午餐,
2026-10-10,08:56:00,支出,28,餐饮,,,TNGewallet,是,是,Main Ledger,LIEW JI SDN. BHD. 消费 早餐刘记粿条仔,
2026-10-10,08:57:00,支出,3.8,餐饮,咖啡,,TNGewallet,是,是,Main Ledger,转账给LIEW CHEE MENG 早餐cham冰,
2026-10-10,19:09:00,支出,28.8,餐饮,餐厅,,PBBank,是,是,Main Ledger,晚餐ayam gepuk,
2026-10-10,21:15:00,支出,4.23,餐饮,咖啡,,TNGewallet,是,是,Main Ledger,Luckin Coffee 消费,
2026-10-11,10:43:00,支出,19.7,餐饮,,,PBBank,是,是,Main Ledger,aliff 宵夜,
2026-10-11,10:44:00,支出,43.8,餐饮,,,PBBank,是,是,Main Ledger,晚餐钱 28啊祥,
2026-10-12,10:49:00,支出,36.42,餐饮,,,TNGewallet,是,是,Main Ledger,sushi mentai 消费 11/10/2026的消费午餐,
2026-10-12,12:33:00,支出,8,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,餐食消费转账 苦瓜汤饭,
2026-10-13,12:03:00,支出,7,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,CONNIE MIXED RICE 餐費,
2026-10-13,13:05:00,支出,14.9,餐饮,饮品,,PBBank,是,是,Main Ledger,bean factory austin,
2026-10-14,12:25:00,支出,8,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,YAN KITCHEN LAD 消费,
2026-10-14,12:47:00,支出,1.4,餐饮,,,TNGewallet,是,是,Main Ledger,转账给SOH YI YANG 中国茶两杯钱,
2026-10-14,13:06:00,支出,5.3,购物,,,PBBank,是,是,Main Ledger,99 买面包,
2026-10-14,18:17:00,支出,41.53,交通,加油充电,,TNGewallet,是,是,Main Ledger,petron打油 回家中,
2026-10-14,20:52:00,收入,7,别人转账,,,TNGewallet,是,,Main Ledger,资金转账收款 youtube premium付费,
2026-10-14,21:42:00,收入,30,别人转账,,,TNGewallet,是,,Main Ledger,接收來自GAN CHIN CHIN的錢包轉賬,
2026-10-15,12:00:00,支出,1.8,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,BUNDA LIN FOOD VALLEY 消费,
2026-10-15,13:08:00,支出,3.44,交通,,,PBBank,是,是,Main Ledger,kempas toll fee,
2026-10-15,22:57:00,支出,41.9,休闲娱乐,订阅会员,,TNGewallet,是,是,Main Ledger,youtube premium family plan,
2026-10-16,13:09:00,支出,29.32,购物,生活用品,,PBBank,是,是,Main Ledger,taobao 买相框自己+姐姐,
2026-10-17,11:28:00,支出,33.6,餐饮,,,PBBank,是,是,Main Ledger,两条鱼面,
2026-10-17,12:30:00,支出,15.5,餐饮,,,TNGewallet,是,是,Main Ledger,炸香蕉,
2026-10-17,14:31:00,支出,4.75,购物,,,TNGewallet,是,是,Main Ledger,Trip.com 购买新加坡4G eSIM,
2026-10-18,16:11:00,支出,4.75,购物,,,TNGewallet,是,是,Main Ledger,Trip.com 购买新加坡4G eSIM,
2026-10-19,13:51:00,支出,9.8,餐饮,,,TNGewallet,是,是,Main Ledger,"给鸡饭钱加中国茶
16.60-7.5+0.70=9.8",
2026-10-19,18:35:00,支出,49.96,交通,加油充电,,TNGewallet,是,是,Main Ledger,打油 在shudai toll,
2026-10-19,20:15:00,收入,25,别人转账,,,TNGewallet,是,,Main Ledger,爸爸买水瓶的钱,
2026-10-19,20:48:00,支出,8.5,购物,生活用品,,TNGewallet,是,是,Main Ledger,MR DIY 消费 玻璃水,
2026-10-20,21:34:00,收入,121.39,别人转账,,,TNGewallet,是,,Main Ledger,"TEE JING HAO 转账收入 用自己的ryt bank 现在欠
200.64",
2026-10-21,08:53:00,收入,18.44,别人转账,,,TNGewallet,是,,Main Ledger,kailun的午餐钱,
2026-10-21,11:55:00,支出,10.8,餐饮,,,TNGewallet,是,是,Main Ledger,吃午餐+中国茶,
2026-10-21,18:30:00,支出,30,交通,过路停车,,TNGewallet,是,是,Main Ledger,tng卡充值30块,
2026-10-21,20:31:00,支出,37,餐饮,外卖外带,,TNGewallet,是,是,Main Ledger,"Foodpanda Malaysia 消费
买奶茶",
2026-10-21,21:19:00,支出,38.15,餐饮,,,TNGewallet,是,是,Main Ledger,"CHATERAISE ABI 支付
买妈妈的蛋糕",
2026-10-22,13:37:00,支出,35.9,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,"转账至DERIC WONG SOON ANG
吃日本拉面的午餐钱",
2026-10-23,12:39:00,支出,9,餐饮,餐厅,,PBBank,是,是,Main Ledger,下午吃杂菜饭,
2026-10-23,19:03:00,支出,8,其他支出,,,PBBank,是,是,Main Ledger,帮忙还钱,
2026-10-23,19:05:00,收入,8,别人转账,,,TNGewallet,是,,Main Ledger,收到TEE JIE YING的DuitNow款项,
2026-10-23,22:45:00,支出,3.8,购物,,,TNGewallet,是,是,Main Ledger,MIX - SUTERA消费,
2026-10-24,20:32:00,收入,70,别人转账,,,TNGewallet,是,,Main Ledger,TEE JING HAO 转账收入,
2026-10-24,20:32:00,支出,50.68,交通,加油充电,,TNGewallet,是,是,Main Ledger,RON95燃油加注,
2026-10-25,14:10:00,支出,15,交通,养车,,TNGewallet,是,是,Main Ledger,"转账给HOSSAIN ISMAIL
洗车钱",
2026-10-26,12:52:00,收入,654,职业收入,,,PBBank,是,,Main Ledger,汽车补贴,
2026-10-27,12:53:00,支出,6,餐饮,,,PBBank,是,是,Main Ledger,下午吃杂菜饭,
2026-10-27,14:25:00,支出,150,投资理财,,,TNGewallet,是,是,Main Ledger,转账至MOOMOO SECURITIES MALAYSIA SDN BHD,
2026-10-27,22:09:00,支出,20,餐饮,饮品,,TNGewallet,是,是,Main Ledger,"PLUS ONE TEA 消费
奶茶",
2026-10-28,12:00:00,收入,2825.75,职业收入,,,PBBank,是,,Main Ledger,,
2026-10-28,12:17:00,支出,8.8,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,YING LAI RESTAURANT 消费,
2026-10-28,17:16:00,支出,500,家用,,,PBBank,是,是,Main Ledger,给妈妈的家用,
2026-10-28,17:18:00,支出,700,车贷,,,PBBank,是,是,Main Ledger,我自己的bezza和姐姐的s70     570+130,
2026-10-28,19:16:00,支出,450,家用,,,PBBank,是,是,Main Ledger,给爸爸的家用,
2026-10-28,20:08:00,支出,3,餐饮,,,TNGewallet,是,是,Main Ledger,"NeoBean BB 消费
买给姐姐豆奶",
2026-10-29,09:45:00,支出,1000,投资理财,,,PBBank,否,否,Main Ledger,转给rytbank,
2026-10-29,13:35:00,支出,25.37,餐饮,,,TNGewallet,是,是,Main Ledger,转账给SOH YI YANG,
2026-10-29,13:39:00,支出,8.35,购物,,,TNGewallet,是,是,Main Ledger,"BEUTEA 消费
买奶茶给JW",
2026-10-29,18:05:00,支出,49.05,交通,加油充电,,PBBank,是,是,Main Ledger,Shell購買FuelSave 95汽油,
2026-10-29,18:09:00,支出,60,交通,交通卡充值,,TNGewallet,是,是,Main Ledger,Touch 'n Go Sdn Bhd 储值卡充值,
2026-10-30,00:14:00,支出,80.88,购物,生活用品,,TNGewallet,是,是,Main Ledger,"PINDUODUO 消费
卖拼豆给JW",
2026-10-30,18:08:00,支出,13.67,餐饮,,,TNGewallet,是,是,Main Ledger,"转账给SOH YI YANG
吃午餐的钱",
2026-10-30,22:24:00,支出,11.6,餐饮,饮品,,TNGewallet,是,是,Main Ledger,RICH BOY BEVERAGES 消费,
2026-10-31,12:43:00,支出,30,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,RESTORAN SANG SANG SANG 餐飲消費,
2026-10-31,14:51:00,支出,14.8,餐饮,饮品,,TNGewallet,是,是,Main Ledger,KULIM ROAD BEST CENDOL 消费,
2026-10-31,19:09:00,支出,29.9,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,AYAM GEPUK- KULAI 消费,
2026-10-31,20:46:00,支出,7,餐饮,,,TNGewallet,是,是,Main Ledger,"转账给JOHNATHAN CHIN WEI KWOK
奶茶",
2026-11-01,19:20:54,支出,95,购物,服饰鞋包,,PBBank,是,是,Main Ledger,nike鞋子 95块,
2026-11-01,21:39:00,支出,12,餐饮,,,TNGewallet,是,是,Main Ledger,Ausitn 消费,
2026-11-02,12:33:00,支出,7,餐饮,,,TNGewallet,是,是,Main Ledger,"CONNIE MIXED RICE
下午杂菜饭",
2026-11-02,12:36:00,支出,0.7,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,"RESTORAN FU CHUN 餐飲消費
喝中国茶",
2026-11-03,12:12:00,支出,7,餐饮,,,TNGewallet,是,是,Main Ledger,"转账给TAN JOO NI
吃苦瓜汤",
2026-11-03,18:09:00,支出,47.34,交通,加油充电,,PBBank,是,是,Main Ledger,在shell打油,
2026-11-04,12:32:00,支出,10.7,餐饮,,,TNGewallet,是,是,Main Ledger,转账给SOH YI YANG,
2026-11-05,12:05:00,支出,1.8,餐饮,饮品,,TNGewallet,是,是,Main Ledger,wiwynn teh tarik,
2026-11-05,20:22:00,收入,14.8,别人转账,,,TNGewallet,是,,Main Ledger,,
2026-11-05,22:24:00,收入,14.8,别人转账,,,TNGewallet,是,,Main Ledger,jingxian 还钱,
2026-11-06,12:00:00,收入,1148.31,职业收入,津贴补助,,PBBank,是,,Main Ledger,,
2026-11-06,12:52:00,支出,8.3,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,吃午餐,
2026-11-07,20:23:00,收入,18.8,别人转账,,,TNGewallet,是,,Main Ledger,买糖水 还我的钱,
2026-11-07,23:04:00,支出,28,休闲娱乐,线下娱乐,,TNGewallet,是,是,Main Ledger,打麻将输钱,
2026-11-07,23:10:00,支出,1000,投资理财,,,PBBank,是,是,Main Ledger,,
2026-11-08,16:56:00,支出,5.9,餐饮,餐厅,,TNGewallet,是,是,Main Ledger,买egglab的东西,
2026-11-08,21:59:00,支出,38.78,交通,加油充电,,PBBank,是,是,Main Ledger,,
日期,时间,类型,金额,转入账户,转出账户,备注
2026-09-22,12:22:11,账户互转,20,TNGewallet,PBBank,转账￥20.00
2026-09-24,12:53:09,账户互转,20,TNGewallet,PBBank,转账￥20.00
2026-09-24,21:21:45,账户互转,50,TNGewallet,CIMB,转账￥50.00
2026-09-29,13:46:02,账户互转,100,TNGewallet,PBBank,转账￥100.00
2026-10-02,21:38:17,账户互转,200,TNGewallet,PBBank,转账￥200.00
2026-10-12,10:54:00,账户互转,50,TNGewallet,PBBank,转钱
2026-10-14,13:07:00,账户互转,100,TNGewallet,PBBank,转账￥100.00
2026-10-19,18:32:00,账户互转,60,TNGewallet,PBBank,装钱给tng 打油
2026-10-19,20:16:00,账户互转,26,PBBank,TNGewallet,转给自己
2026-10-27,13:56:00,账户互转,650,TNGewallet,PBBank,转账给自己
2026-11-03,18:08:00,账户互转,100,PBBank,TNGewallet,转账￥100
"""#
}
