import AppKit
import SwiftUI

@main
struct CueFetchMain {
    @MainActor private static var appDelegate: AppDelegate?

    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        appDelegate = delegate
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = DownloadStore()
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSWindow.allowsAutomaticWindowTabbing = false
        configureMainMenu()
        showMainWindow()
        DispatchQueue.main.async { [weak self] in
            self?.repairMainWindowFrame()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.repairMainWindowFrame()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    private func showMainWindow() {
        let window = mainWindow ?? makeMainWindow()
        mainWindow = window
        window.setFrame(targetFrame, display: true, animate: false)
        window.setContentSize(NSSize(width: 1040, height: 720))
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeMainWindow() -> NSWindow {
        let rootView = ContentView(store: store)
            .frame(minWidth: 960, minHeight: 660)
            .preferredColorScheme(.light)

        let window = NSWindow(
            contentRect: centeredFrame(width: 1040, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CueFetch"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.minSize = NSSize(width: 960, height: 660)
        window.contentMinSize = NSSize(width: 960, height: 660)
        window.contentView = NSHostingView(rootView: rootView)
        window.delegate = self
        window.isReleasedWhenClosed = false
        return window
    }

    private func repairMainWindowFrame() {
        let window = mainWindow ?? makeMainWindow()
        mainWindow = window
        let frame = targetFrame
        let visibleFrame = NSScreen.main?.visibleFrame ?? frame
        let tooSmall = window.frame.width < 900 || window.frame.height < 620
        let offscreen = !visibleFrame.intersects(window.frame)

        if tooSmall || offscreen {
            window.setFrame(frame, display: true, animate: false)
            window.setContentSize(NSSize(width: 1040, height: 720))
        }

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private var targetFrame: NSRect {
        centeredFrame(width: 1040, height: 720)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "CueFetch")
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Settings...", action: #selector(showSettingsFromMenu(_:)), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit CueFetch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Paste and Match Style", action: #selector(NSTextView.pasteAsPlainText(_:)), keyEquivalent: "V")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    @objc private func showSettingsFromMenu(_ sender: Any?) {
        store.isShowingSettings = true
        showMainWindow()
    }

    private func centeredFrame(width: CGFloat, height: CGFloat) -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: width, height: height)
        let targetWidth = min(width, screenFrame.width - 48)
        let targetHeight = min(height, screenFrame.height - 48)
        return NSRect(
            x: screenFrame.midX - targetWidth / 2,
            y: screenFrame.midY - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )
    }
}
