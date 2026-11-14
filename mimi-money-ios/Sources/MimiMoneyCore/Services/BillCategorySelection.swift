import Foundation

/// Parsed / pending category choice for bill-detail「标准分类」picker.
public struct BillCategorySelection: Equatable, Sendable {
    public var type: TransactionType
    public var primaryId: String?
    public var secondaryId: String?

    public init(type: TransactionType, primaryId: String? = nil, secondaryId: String? = nil) {
        self.type = type
        self.primaryId = primaryId
        self.secondaryId = secondaryId
    }

    public var categoryPath: String {
        // Resolved by caller with live groups; this is only a fallback key.
        ""
    }

    /// Build selection from a bill's stored path (`一级` or `一级-二级`) and type.
    public static func from(
        type: TransactionType,
        categoryPath: String,
        expenseCategories: [CategoryGroup],
        incomeCategories: [CategoryGroup]
    ) -> BillCategorySelection {
        let groups = type == .income ? incomeCategories : expenseCategories
        let parts = categoryPath
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let primaryName = parts.first,
              let group = groups.first(where: { $0.name == primaryName }) else {
            return BillCategorySelection(type: type == .transfer ? .expense : type)
        }

        if parts.count >= 2 {
            let subName = parts[1]
            if let sub = group.subcategories.first(where: { $0.name == subName }) {
                return BillCategorySelection(type: type, primaryId: group.id, secondaryId: sub.id)
            }
        }
        return BillCategorySelection(type: type, primaryId: group.id, secondaryId: nil)
    }

    public func resolvedPath(in groups: [CategoryGroup]) -> (path: String, iconName: String)? {
        guard let primaryId,
              let group = groups.first(where: { $0.id == primaryId }) else { return nil }
        if let secondaryId,
           let sub = group.subcategories.first(where: { $0.id == secondaryId }) {
            return ("\(group.name)-\(sub.name)", sub.iconName)
        }
        return (group.name, group.displayBadgeToken)
    }
}
