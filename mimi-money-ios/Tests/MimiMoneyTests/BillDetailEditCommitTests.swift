import XCTest
@testable import MimiMoneyCore

final class BillDetailEditCommitTests: XCTestCase {
    private func sampleBill(amount: Double = 42.5) -> TransactionItem {
        TransactionItem(
            type: .expense,
            categoryPath: "餐饮-餐厅",
            iconName: "🍜",
            amount: amount,
            accountName: "TNGewallet",
            note: "午餐",
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func testValidAmountOverridesDraft() {
        var draft = sampleBill(amount: 10)
        draft.note = "改备注"
        let prepared = BillDetailEditCommit.prepared(
            draft: draft,
            amountString: "88.20",
            discountString: "1.5",
            refundString: "2",
            previousValidAmount: 10
        )
        XCTAssertEqual(prepared.amount, 88.20, accuracy: 0.001)
        XCTAssertEqual(prepared.discountAmount, 1.5, accuracy: 0.001)
        XCTAssertEqual(prepared.refundOrCashback ?? -1, 2, accuracy: 0.001)
        XCTAssertEqual(prepared.note, "改备注")
    }

    func testEmptyAmountKeepsPreviousValid() {
        let draft = sampleBill(amount: 0) // keypad may have zeroed draft
        let prepared = BillDetailEditCommit.prepared(
            draft: draft,
            amountString: "",
            discountString: "",
            refundString: "",
            previousValidAmount: 42.5
        )
        XCTAssertEqual(prepared.amount, 42.5, accuracy: 0.001)
        XCTAssertEqual(prepared.discountAmount, 0, accuracy: 0.001)
        XCTAssertNil(prepared.refundOrCashback)
    }

    func testZeroAmountKeepsPreviousValid() {
        let prepared = BillDetailEditCommit.prepared(
            draft: sampleBill(amount: 0),
            amountString: "0",
            discountString: "0",
            refundString: "",
            previousValidAmount: 19.9
        )
        XCTAssertEqual(prepared.amount, 19.9, accuracy: 0.001)
    }

    func testZeroPointZeroAmountKeepsPreviousValid() {
        let prepared = BillDetailEditCommit.prepared(
            draft: sampleBill(amount: 5),
            amountString: "0.00",
            discountString: "",
            refundString: "",
            previousValidAmount: 5
        )
        XCTAssertEqual(prepared.amount, 5, accuracy: 0.001)
    }

    func testNonNumericAmountKeepsPreviousValid() {
        let prepared = BillDetailEditCommit.prepared(
            draft: sampleBill(amount: 3),
            amountString: "abc",
            discountString: "x",
            refundString: "y",
            previousValidAmount: 33
        )
        XCTAssertEqual(prepared.amount, 33, accuracy: 0.001)
        XCTAssertEqual(prepared.discountAmount, 0, accuracy: 0.001)
        XCTAssertNil(prepared.refundOrCashback)
    }

    func testResolvedAmountHelpers() {
        XCTAssertEqual(BillDetailEditCommit.resolvedAmount(from: "12.34", fallback: 1), 12.34, accuracy: 0.001)
        XCTAssertEqual(BillDetailEditCommit.resolvedAmount(from: "  ", fallback: 9), 9, accuracy: 0.001)
        XCTAssertEqual(BillDetailEditCommit.resolvedAmount(from: "-5", fallback: 9), 9, accuracy: 0.001)
        XCTAssertEqual(BillDetailEditCommit.resolvedDiscount(from: ""), 0, accuracy: 0.001)
        XCTAssertEqual(BillDetailEditCommit.resolvedDiscount(from: "3.1"), 3.1, accuracy: 0.001)
        XCTAssertNil(BillDetailEditCommit.resolvedRefund(from: ""))
        XCTAssertEqual(BillDetailEditCommit.resolvedRefund(from: "4.2") ?? -1, 4.2, accuracy: 0.001)
    }
}
