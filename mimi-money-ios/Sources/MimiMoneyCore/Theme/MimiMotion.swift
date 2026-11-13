import SwiftUI

/// Shared motion tokens — Apple-like, snappy, one style across the app.
/// Prefer these over ad-hoc springs / easeInOut on full-screen trees.
public enum MimiMotion {
    /// Settled duration used for sequential handoffs (close A → open B).
    public static let pageDuration: TimeInterval = 0.28
    public static let sheetDuration: TimeInterval = 0.26
    public static let drawerDuration: TimeInterval = 0.26

    /// Snappy push — light bounce, like UINavigationController.
    public static var page: Animation {
        .spring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.08)
    }

    /// Slightly faster dismiss.
    public static var pageDismiss: Animation {
        .spring(response: 0.28, dampingFraction: 0.92, blendDuration: 0.06)
    }

    /// Bottom sheet / AI composer.
    public static var sheet: Animation {
        .spring(response: 0.30, dampingFraction: 0.86, blendDuration: 0.06)
    }

    /// Drawer slide.
    public static var drawer: Animation {
        .spring(response: 0.30, dampingFraction: 0.90, blendDuration: 0.06)
    }

    /// Chips, panels, delete reveal, toggles, toasts.
    public static var quick: Animation {
        .spring(response: 0.22, dampingFraction: 0.86, blendDuration: 0.04)
    }

    /// Drag follow / rubber-band settle.
    public static var interactive: Animation {
        .interactiveSpring(response: 0.28, dampingFraction: 0.86, blendDuration: 0.08)
    }

    /// Fade-only fallback when Reduce Motion is on.
    public static var fade: Animation {
        .easeOut(duration: 0.15)
    }

    /// Full-screen page: pure horizontal slide (no opacity — avoids muddy/janky fades).
    public static var pagePushTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .trailing)
        )
    }

    public static var sheetTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }

    public static var snippetTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        )
    }

    public static func page(reduceMotion: Bool) -> Animation {
        reduceMotion ? fade : Self.page
    }

    public static func pageDismiss(reduceMotion: Bool) -> Animation {
        reduceMotion ? fade : Self.pageDismiss
    }

    public static func sheet(reduceMotion: Bool) -> Animation {
        reduceMotion ? fade : Self.sheet
    }

    public static func drawer(reduceMotion: Bool) -> Animation {
        reduceMotion ? fade : Self.drawer
    }

    public static func quick(reduceMotion: Bool) -> Animation {
        reduceMotion ? fade : Self.quick
    }

    public static func interactive(reduceMotion: Bool) -> Animation {
        reduceMotion ? fade : Self.interactive
    }

    public static func pageTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : pagePushTransition
    }

    /// Delay before opening the next surface after closing the previous one.
    public static func handoffDelay(
        _ kind: HandoffKind = .page,
        reduceMotion: Bool
    ) -> TimeInterval {
        if reduceMotion { return 0.10 }
        switch kind {
        case .page: return pageDuration + 0.02
        case .sheet: return sheetDuration + 0.02
        case .drawer: return drawerDuration + 0.02
        }
    }

    public enum HandoffKind {
        case page
        case sheet
        case drawer
    }
}
