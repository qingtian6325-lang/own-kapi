import XCTest
@testable import MimiMoneyCore

final class MimiGesturePolicyTests: XCTestCase {
    func testHorizontalDominantPrefersAxisWithRatio() {
        XCTAssertTrue(MimiGesturePolicy.isHorizontalDominant(dx: 40, dy: 10))
        XCTAssertFalse(MimiGesturePolicy.isHorizontalDominant(dx: 10, dy: 40))
        XCTAssertFalse(MimiGesturePolicy.isHorizontalDominant(dx: 5, dy: 5))
    }

    func testVerticalDominantPrefersAxisWithRatio() {
        XCTAssertTrue(MimiGesturePolicy.isVerticalDominant(dx: 10, dy: 40))
        XCTAssertFalse(MimiGesturePolicy.isVerticalDominant(dx: 40, dy: 10))
    }

    func testEdgeBackCommitsOnDistanceOrVelocity() {
        XCTAssertTrue(
            MimiGesturePolicy.shouldCommitEdgeBack(
                translationX: 100,
                predictedEndX: 100,
                velocityX: 0
            )
        )
        XCTAssertTrue(
            MimiGesturePolicy.shouldCommitEdgeBack(
                translationX: 40,
                predictedEndX: 40,
                velocityX: 800
            )
        )
        XCTAssertFalse(
            MimiGesturePolicy.shouldCommitEdgeBack(
                translationX: 20,
                predictedEndX: 30,
                velocityX: 100
            )
        )
        XCTAssertFalse(
            MimiGesturePolicy.shouldCommitEdgeBack(
                translationX: -10,
                predictedEndX: -10,
                velocityX: 900
            )
        )
    }

    func testRubberBandTracksFingerThenDampsOverflow() {
        let width: CGFloat = 390
        XCTAssertEqual(MimiGesturePolicy.rubberBandOffset(translationX: 80, containerWidth: width), 80, accuracy: 0.01)
        let over = MimiGesturePolicy.rubberBandOffset(translationX: width + 120, containerWidth: width)
        XCTAssertGreaterThan(over, width)
        XCTAssertLessThan(over, width + width * MimiGesturePolicy.rubberBandCapFraction + 1)
        let left = MimiGesturePolicy.rubberBandOffset(translationX: -40, containerWidth: width)
        XCTAssertLessThan(left, 0)
        XCTAssertGreaterThan(left, -40)
    }
}
