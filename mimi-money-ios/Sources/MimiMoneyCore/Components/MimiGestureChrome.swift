import SwiftUI

/// Interactive edge-swipe-back for ZStack “pushed” feature pages (not UINavigationController).
/// Tracks the finger with rubber-band rebound via `MimiMotion.interactive`.
public struct MimiEdgeSwipeBackModifier: ViewModifier {
    public var onBack: () -> Void
    public var isEnabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var containerWidth: CGFloat = 320

    public init(isEnabled: Bool = true, onBack: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.onBack = onBack
    }

    public func body(content: Content) -> some View {
        content
            .offset(x: dragOffset)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { containerWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, w in containerWidth = w }
                }
            )
            .simultaneousGesture(edgeSwipeGesture)
            .animation(
                isDragging
                    ? nil
                    : MimiMotion.interactive(reduceMotion: reduceMotion),
                value: dragOffset
            )
    }

    private var edgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard isEnabled else { return }
                // Only start from the leading edge.
                let startX = value.startLocation.x
                guard startX <= MimiGesturePolicy.edgeActivationWidth else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard MimiGesturePolicy.isHorizontalDominant(dx: dx, dy: dy) || isDragging else {
                    return
                }
                // Only swipe-from-left (positive dx) dismisses.
                guard dx > 0 || isDragging else { return }
                isDragging = true
                dragOffset = MimiGesturePolicy.rubberBandOffset(
                    translationX: dx,
                    containerWidth: max(containerWidth, 1)
                )
            }
            .onEnded { value in
                guard isEnabled, isDragging else {
                    isDragging = false
                    dragOffset = 0
                    return
                }
                let dx = value.translation.width
                let predicted = value.predictedEndTranslation.width
                // Approximate velocity from predicted end vs current translation.
                let velocity = (predicted - dx) * 12
                let commit = MimiGesturePolicy.shouldCommitEdgeBack(
                    translationX: dx,
                    predictedEndX: predicted,
                    velocityX: velocity
                )
                if commit {
                    // Slide off then fire dismiss (pageDismiss spring lives in parent).
                    withAnimation(MimiMotion.pageDismiss(reduceMotion: reduceMotion)) {
                        dragOffset = max(containerWidth, 1)
                    }
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + (reduceMotion ? 0.02 : 0.12)
                    ) {
                        dragOffset = 0
                        isDragging = false
                        onBack()
                    }
                } else {
                    // Rubber-band rebound to rest.
                    withAnimation(MimiMotion.interactive(reduceMotion: reduceMotion)) {
                        dragOffset = 0
                    }
                    isDragging = false
                }
            }
    }
}

#if os(iOS)
private struct MimiInteractiveSheetModifier: ViewModifier {
    var detents: Set<PresentationDetent>?
    var showDragIndicator: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        // Do NOT force interactiveDismissDisabled(false) here — bookkeeping (v1.3.13 / #7)
        // temporarily disables dismiss during horizontal-dominant 支出|收入|转账 paging.
        if let detents {
            content
                .presentationDetents(detents)
                .presentationDragIndicator(showDragIndicator ? .visible : .hidden)
                .presentationContentInteraction(.scrolls)
        } else {
            content
                .presentationDragIndicator(showDragIndicator ? .visible : .hidden)
                .presentationContentInteraction(.scrolls)
        }
    }
}
#endif

public extension View {
    /// System sheet chrome: swipe-down dismiss stays enabled; content scrolls win over
    /// resize so vertical drag feels like dismiss. Compatible with bookkeeping’s
    /// `presentationContentInteraction(.scrolls)` + axis lock from v1.3.13 (#7).
    func mimiInteractiveSheet(
        detents: Set<PresentationDetent>? = nil,
        showDragIndicator: Bool = true
    ) -> some View {
        #if os(iOS)
        modifier(MimiInteractiveSheetModifier(detents: detents, showDragIndicator: showDragIndicator))
        #else
        self
        #endif
    }

    /// Finger-tracking edge swipe-back for overlay feature pages.
    func mimiEdgeSwipeBack(isEnabled: Bool = true, onBack: @escaping () -> Void) -> some View {
        modifier(MimiEdgeSwipeBackModifier(isEnabled: isEnabled, onBack: onBack))
    }
}
