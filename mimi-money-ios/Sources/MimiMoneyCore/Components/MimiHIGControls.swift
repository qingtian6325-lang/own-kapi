import SwiftUI

/// Apple HIG helpers: 44pt hit targets + light press feedback.
public enum MimiHIG {
    public static let minTouch: CGFloat = 44
}

public struct MimiPressableButtonStyle: ButtonStyle {
    public var pressedOpacity: Double

    public init(pressedOpacity: Double = 0.55) {
        self.pressedOpacity = pressedOpacity
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

public extension View {
    /// Expand the tappable area to at least 44×44 pt without forcing a larger visual.
    func mimiMinTouchTarget(_ size: CGFloat = MimiHIG.minTouch) -> some View {
        frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }

    func mimiPressable() -> some View {
        buttonStyle(MimiPressableButtonStyle())
    }
}
