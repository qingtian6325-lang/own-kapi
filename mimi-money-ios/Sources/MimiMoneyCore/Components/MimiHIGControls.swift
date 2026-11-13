import SwiftUI

/// Apple HIG helpers: 44pt hit targets + light press feedback.
public enum MimiHIG {
    public static let minTouch: CGFloat = 44
}

/// Native-feeling press: opacity + slight scale within ~100ms (HIG feedback).
public struct MimiPressableButtonStyle: ButtonStyle {
    public var pressedOpacity: Double
    public var pressedScale: CGFloat

    public init(pressedOpacity: Double = 0.55, pressedScale: CGFloat = 0.97) {
        self.pressedOpacity = pressedOpacity
        self.pressedScale = pressedScale
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// Shared 手动 ↔ AI mode switch chip (same icon + capsule on both sides).
public struct BookkeepingModeSwitchButton: View {
    public var title: String
    public var accessibilityName: String?
    public var action: () -> Void

    public init(
        title: String,
        accessibilityName: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.accessibilityName = accessibilityName
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.left.arrow.right")
                    .mimiFont(13, weight: .bold)
                Text(title)
                    .mimiFont(13, weight: .semibold)
            }
            .foregroundColor(MimiTheme.textPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(minHeight: MimiHIG.minTouch)
            .background(Capsule().strokeBorder(MimiTheme.strokeSubtle, lineWidth: 1))
        }
        .mimiPressable()
        .accessibilityLabel(accessibilityName ?? "切换到\(title)")
    }
}

public extension View {
    /// Expand the tappable area to at least 44×44 pt without forcing a larger visual.
    func mimiMinTouchTarget(_ size: CGFloat = MimiHIG.minTouch) -> some View {
        frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }

    /// Prefer this over `.buttonStyle(.plain)` for interactive controls.
    func mimiPressable() -> some View {
        buttonStyle(MimiPressableButtonStyle())
    }

    /// Amounts that must stay readable under Dynamic Type / narrow layouts.
    func mimiAmountFit(lines: Int = 1) -> some View {
        lineLimit(lines)
            .minimumScaleFactor(0.7)
    }
}
