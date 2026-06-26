import AppKit
import SwiftUI

struct MainWindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WindowProbeView {
        let view = WindowProbeView()
        view.onWindowAvailable = { window in
            configure(window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: WindowProbeView, context: Context) {
        nsView.onWindowAvailable = { window in
            configure(window, coordinator: context.coordinator)
        }
        if let window = nsView.window {
            configure(window, coordinator: context.coordinator)
        }
    }

    private func configure(_ window: NSWindow, coordinator: Coordinator) {
        guard !coordinator.didConfigure else {
            return
        }
        coordinator.didConfigure = true
        window.minSize = NSSize(width: 980, height: 700)
        window.setContentSize(NSSize(width: 1040, height: 760))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    final class Coordinator {
        var didConfigure = false
    }
}

final class WindowProbeView: NSView {
    var onWindowAvailable: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                self.onWindowAvailable?(window)
            }
        }
    }
}
