import SwiftUI

#if canImport(UIKit) && os(iOS)
import UIKit

/// Re-enables `UINavigationController.interactivePopGestureRecognizer` when
/// SwiftUI hides the system back button (`navigationBarBackButtonHidden(true)`).
/// Without this, custom chevron.left toolbars kill edge-swipe-back.
struct MimiInteractivePopGestureEnabler: UIViewControllerRepresentable {
    var isEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isEnabled: isEnabled)
    }

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        context.coordinator.isEnabled = isEnabled
        uiViewController.onAppearInHierarchy = { [weak uiViewController] in
            guard let host = uiViewController else { return }
            context.coordinator.attach(to: host)
        }
        // Retry after layout — NavigationStack may not have wired the UINavigationController yet.
        DispatchQueue.main.async {
            context.coordinator.attach(to: uiViewController)
        }
    }

    final class Controller: UIViewController {
        var onAppearInHierarchy: (() -> Void)?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onAppearInHierarchy?()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            onAppearInHierarchy?()
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled: Bool
        private weak var navigationController: UINavigationController?

        init(isEnabled: Bool) {
            self.isEnabled = isEnabled
        }

        func attach(to host: UIViewController) {
            guard let nav = Self.resolveNavigationController(from: host) else { return }
            navigationController = nav
            guard let gesture = nav.interactivePopGestureRecognizer else { return }
            gesture.isEnabled = isEnabled && nav.viewControllers.count > 1
            gesture.delegate = self
            gesture.cancelsTouchesInView = false
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled else { return false }
            return (navigationController?.viewControllers.count ?? 0) > 1
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private static func resolveNavigationController(from host: UIViewController) -> UINavigationController? {
            if let nav = host.navigationController { return nav }
            var parent = host.parent
            while let p = parent {
                if let nav = p as? UINavigationController { return nav }
                if let nav = p.navigationController { return nav }
                parent = p.parent
            }
            return nil
        }
    }
}
#endif

public extension View {
    /// Restore iOS interactive edge-swipe-back when using a custom back control
    /// with `navigationBarBackButtonHidden(true)`.
    func mimiInteractivePopGestureEnabled(_ enabled: Bool = true) -> some View {
        #if canImport(UIKit) && os(iOS)
        background(
            MimiInteractivePopGestureEnabler(isEnabled: enabled)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
        #else
        self
        #endif
    }
}
