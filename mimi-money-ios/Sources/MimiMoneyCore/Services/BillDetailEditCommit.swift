import Foundation

/// Pure helpers for bill-detail leave-to-save: merge editable strings onto a draft
/// without silently writing empty/zero amounts over a previously valid value.
public enum BillDetailEditCommit {
    /// Parse amount text. Empty, non-numeric, or ≤0 keeps `fallback`.
    public static func resolvedAmount(from amountString: String, fallback: Double) -> Double {
        let trimmed = amountString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Double(trimmed), parsed > 0 else {
            return fallback
        }
        return parsed
    }

    public static func resolvedDiscount(from discountString: String) -> Double {
        let trimmed = discountString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parsed = Double(trimmed) else { return 0 }
        return max(0, parsed)
    }

    /// Empty / non-numeric → `nil` (clears optional refund). Invalid numbers → `nil`.
    public static func resolvedRefund(from refundString: String) -> Double? {
        let trimmed = refundString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parsed = Double(trimmed) else { return nil }
        return parsed
    }

    /// Apply amount / discount / refund string fields onto `draft`.
    /// `previousValidAmount` is the amount when the detail screen opened (or last known good).
    public static func prepared(
        draft: TransactionItem,
        amountString: String,
        discountString: String,
        refundString: String,
        previousValidAmount: Double
    ) -> TransactionItem {
        var bill = draft
        bill.amount = resolvedAmount(from: amountString, fallback: previousValidAmount)
        bill.discountAmount = resolvedDiscount(from: discountString)
        bill.refundOrCashback = resolvedRefund(from: refundString)
        return bill
    }
}
