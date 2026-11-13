import Foundation

public enum MimiCSVService {
    /// Official paste/copy template (matches export headers). Keep UI and parser in sync.
    public static let standardImportTemplate: String = """
    日期,时间,类型,金额,一级分类,二级分类,标签,账户,计入收支,计入预算,所属账本,备注,分摊明细
    2026-11-08,21:59:00,支出,38.78,交通,加油充电,,PBBank,是,是,Main Ledger,示例支出,
    2026-11-08,16:56:34,支出,5.90,餐饮,餐厅,,TNG eWallet,是,是,Main Ledger,示例午餐,
    2026-11-06,10:00:00,收入,1000.00,职业收入,工资,,CIMB,是,,Main Ledger,示例收入,
    """

    /// Parses Mimi Money's dual-table CSV export format (supporting RFC-4180 multiline quoted fields):
    /// Table 1: 日期,时间,类型,金额,一级分类,二级分类,标签,账户,计入收支,计入预算,所属账本,备注,分摊明细
    /// Simplified: 日期,时间,类型,金额,一级分类,二级分类,账户,备注
    /// Table 2: 日期,时间,类型,金额,转入账户,转出账户,备注
    public static func parseMimiCSV(_ csvText: String) -> [TransactionItem] {
        let rows = parseCSVRows(csvText)
        var items: [TransactionItem] = []
        var map = ColumnMap.fullExpenseIncome
        let cal = Calendar(identifier: .gregorian)

        for (rowIdx, row) in rows.enumerated() {
            guard !row.isEmpty else { continue }
            let firstCol = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if firstCol.isEmpty { continue }

            if firstCol == "日期" {
                map = ColumnMap.fromHeader(row)
                continue
            }

            guard row.count >= 4 else { continue }
            let dateStr = cell(row, map.date)
            let timeStr = cell(row, map.time)
            let typeStr = cell(row, map.type)
            let amountStr = cell(row, map.amount)
            guard let amount = Double(amountStr), amount > 0 else { continue }

            let billDate = parseDateTime(dateStr: dateStr, timeStr: timeStr, calendar: cal)
            let deterministicUUID = makeDeterministicUUID(index: rowIdx + 1)

            if map.isTransfer || typeStr == "账户互转" || typeStr == "转账" {
                let toAccountName = cell(row, map.transferTo, fallback: "TNGewallet")
                let fromAccountName = cell(row, map.transferFrom, fallback: "PBBank")
                let note = cell(row, map.note)

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
                let txType: TransactionType = (typeStr == "收入") ? .income : .expense
                let primaryCatName = cell(row, map.primaryCat, fallback: "餐饮")
                let subCatName = cell(row, map.subCat)
                let tagText = map.tags >= 0 ? cell(row, map.tags) : ""
                let accountName = cell(row, map.account, fallback: "TNGewallet")
                let includeInStatsStr = map.includeStats >= 0 ? cell(row, map.includeStats, fallback: "是") : "是"
                let includeInBudgetStr = map.includeBudget >= 0 ? cell(row, map.includeBudget, fallback: "是") : "是"
                let ledgerName = map.ledger >= 0 ? cell(row, map.ledger, fallback: "Main Ledger") : "Main Ledger"
                let note = cell(row, map.note)

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

    private struct ColumnMap {
        var date = 0
        var time = 1
        var type = 2
        var amount = 3
        var primaryCat = 4
        var subCat = 5
        var tags = 6
        var account = 7
        var includeStats = 8
        var includeBudget = 9
        var ledger = 10
        var note = 11
        var transferTo = 4
        var transferFrom = 5
        var isTransfer = false

        static var fullExpenseIncome: ColumnMap { ColumnMap() }

        static func fromHeader(_ row: [String]) -> ColumnMap {
            let cols = row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            var map = ColumnMap()
            func idx(_ name: String) -> Int? {
                cols.firstIndex(where: { $0 == name || $0.contains(name) })
            }

            if cols.contains(where: { $0.contains("转入账户") }) {
                map.isTransfer = true
                map.transferTo = idx("转入账户") ?? 4
                map.transferFrom = idx("转出账户") ?? 5
                map.note = idx("备注") ?? 6
                map.tags = -1
                map.account = -1
                map.includeStats = -1
                map.includeBudget = -1
                map.ledger = -1
                map.primaryCat = -1
                map.subCat = -1
                return map
            }

            map.date = idx("日期") ?? 0
            map.time = idx("时间") ?? 1
            map.type = idx("类型") ?? 2
            map.amount = idx("金额") ?? 3
            map.primaryCat = idx("一级分类") ?? 4
            map.subCat = idx("二级分类") ?? 5
            map.tags = idx("标签") ?? -1
            map.account = idx("账户") ?? (map.tags >= 0 ? 7 : 6)
            map.includeStats = idx("计入收支") ?? -1
            map.includeBudget = idx("计入预算") ?? -1
            map.ledger = idx("所属账本") ?? -1
            map.note = idx("备注") ?? (map.ledger >= 0 ? 11 : (map.account >= 0 ? map.account + 1 : 7))
            return map
        }
    }

    private static func cell(_ row: [String], _ index: Int, fallback: String = "") -> String {
        guard index >= 0, index < row.count else { return fallback }
        let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? fallback : value
    }

    /// Exports transactions to Mimi Money's dual-table CSV format
    public static func exportMimiCSV(transactions: [TransactionItem]) -> String {
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
}
