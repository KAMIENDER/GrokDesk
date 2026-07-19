import AppKit
import SwiftUI

/// Bridges the host `NSWindow` fullscreen state into SwiftUI without making
/// the rest of the sidebar depend on AppKit lifecycle details.
struct WindowFullscreenObserver: NSViewRepresentable {
    @Binding var isFullScreen: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isFullScreen: $isFullScreen)
    }

    func makeNSView(context: Context) -> WindowAttachmentView {
        let view = WindowAttachmentView()
        view.windowDidChange = { window in
            context.coordinator.observe(window: window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowAttachmentView, context: Context) {
        context.coordinator.isFullScreen = $isFullScreen
        context.coordinator.observe(window: nsView.window)
    }

    static func dismantleNSView(_ nsView: WindowAttachmentView, coordinator: Coordinator) {
        coordinator.stopObserving()
        nsView.windowDidChange = nil
    }

    final class Coordinator {
        var isFullScreen: Binding<Bool>
        private weak var observedWindow: NSWindow?
        private var observers: [NSObjectProtocol] = []

        init(isFullScreen: Binding<Bool>) {
            self.isFullScreen = isFullScreen
        }

        func observe(window: NSWindow?) {
            guard observedWindow !== window else {
                publish(window)
                return
            }

            stopObserving()
            observedWindow = window
            guard let window else {
                publish(nil)
                return
            }

            let center = NotificationCenter.default
            for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
                observers.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    self?.publish(window)
                })
            }
            publish(window)
        }

        func stopObserving() {
            let center = NotificationCenter.default
            observers.forEach(center.removeObserver)
            observers.removeAll()
            observedWindow = nil
        }

        private func publish(_ window: NSWindow?) {
            let newValue = window?.styleMask.contains(.fullScreen) == true
            guard isFullScreen.wrappedValue != newValue else { return }
            DispatchQueue.main.async { [weak self] in
                self?.isFullScreen.wrappedValue = newValue
            }
        }
    }
}

final class WindowAttachmentView: NSView {
    var windowDidChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowDidChange?(window)
    }
}
