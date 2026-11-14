import Foundation
import CoreGraphics

/// Shared thresholds for interactive sheet dismiss vs edge-swipe-back.
/// Pure functions so unit tests can lock finger-tracking / rubber-band behavior
/// without UIKit.
public enum MimiGesturePolicy {
    /// Left-edge width (pt) that starts an interactive edge-pop / overlay back swipe.
    public static let edgeActivationWidth: CGFloat = 22

    /// Minimum horizontal travel before we treat the drag as a committed back swipe.
    public static let edgeCommitDistance: CGFloat = 88

    /// Velocity (pt/s) that commits pop even below distance threshold.
    public static let edgeCommitVelocity: CGFloat = 650

    /// Cap rubber-band overscroll past the leading edge (fraction of width).
    public static let rubberBandCapFraction: CGFloat = 0.18

    /// Prefer horizontal when |dx| clearly exceeds |dy| (avoids fighting vertical scroll).
    public static func isHorizontalDominant(
        dx: CGFloat,
        dy: CGFloat,
        ratio: CGFloat = 1.25,
        minDistance: CGFloat = 12
    ) -> Bool {
        let ax = abs(dx)
        let ay = abs(dy)
        guard ax >= minDistance || ay >= minDistance else { return false }
        return ax > ay * ratio
    }

    public static func isVerticalDominant(
        dx: CGFloat,
        dy: CGFloat,
        ratio: CGFloat = 1.25,
        minDistance: CGFloat = 12
    ) -> Bool {
        let ax = abs(dx)
        let ay = abs(dy)
        guard ax >= minDistance || ay >= minDistance else { return false }
        return ay > ax * ratio
    }

    /// Whether a left-edge drag should dismiss / pop.
    /// - Parameters:
    ///   - translationX: positive = finger moved right (system pop direction).
    ///   - predictedEndX: predicted translation including velocity.
    ///   - velocityX: points per second.
    public static func shouldCommitEdgeBack(
        translationX: CGFloat,
        predictedEndX: CGFloat,
        velocityX: CGFloat,
        commitDistance: CGFloat = edgeCommitDistance,
        commitVelocity: CGFloat = edgeCommitVelocity
    ) -> Bool {
        guard translationX > 0 else { return false }
        if velocityX >= commitVelocity { return true }
        if translationX >= commitDistance { return true }
        if predictedEndX >= commitDistance * 1.15 { return true }
        return false
    }

    /// Rubber-band offset for interactive follow: tracks finger while x ≥ 0,
    /// damps when overscrolled past container width.
    public static func rubberBandOffset(
        translationX: CGFloat,
        containerWidth: CGFloat
    ) -> CGFloat {
        guard containerWidth > 0 else { return max(0, translationX) }
        if translationX <= 0 {
            // Slight resistance pulling left of origin.
            return translationX * 0.22
        }
        if translationX <= containerWidth {
            return translationX
        }
        let overflow = translationX - containerWidth
        let cap = containerWidth * rubberBandCapFraction
        let damped = overflow / (1 + overflow / max(cap, 1))
        return containerWidth + min(damped, cap)
    }
}
