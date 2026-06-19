import SwiftUI
import AppKit
import os

// Taskdown is a menu bar accessory. AppKit owns the status item and the custom
// borderless panel; the content is SwiftUI. A borderless NSPanel is used
// instead of NSPopover because NSPopover can visibly re-anchor itself after its
// first SwiftUI layout pass.

@main
enum Main {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let menuBarGap: CGFloat = 1
    private let panelSize = NSSize(width: 780, height: 660)
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store = WeekStore()
    private let logger = Logger(subsystem: "com.taskdown.app", category: "popover")

    private var panel: TaskdownPanel?
    private var window: NSWindow?
    private var globalMonitor: Any?
    private var keyMonitor: Any?
    private var defaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Default to staying open and floating above other windows; the user
        // can turn this off in Settings.
        UserDefaults.standard.register(defaults: [SettingsKey.pinned: true])

        if let button = statusItem.button {
            button.image = StatusIcon.taskdown
            button.action = #selector(togglePopover)
            button.target = self
        }

        store.onRequestClose = { [weak self] in
            self?.closePopover()
        }
        store.onOpenInWindow = { [weak self] in
            self?.openInWindow()
        }

        installMainMenu()
        createPanel()
        // The key monitor stays installed for the whole session so app-level
        // shortcuts (day navigation, New Week, Cmd+W) work whether the popover
        // or the pop-out window is focused.
        installKeyMonitor()

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyPinnedBehavior()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flushPendingSave()
        removeGlobalMonitor()
        removeKeyMonitor()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit Taskdown",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let newWeekItem = fileMenu.addItem(
            withTitle: "New Week",
            action: #selector(newWeekMenu),
            keyEquivalent: "n"
        )
        newWeekItem.target = self
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(
            withTitle: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            withTitle: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    @objc private func newWeekMenu() {
        store.addNewWeek()
    }

    /// Pop the content out into a normal resizable window, sharing the same
    /// store as the popover so both always show the same data.
    private func openInWindow() {
        closePopover()
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.title = "Taskdown"
            win.titleVisibility = .hidden
            win.titlebarAppearsTransparent = true
            win.isReleasedWhenClosed = false
            win.appearance = NSAppearance(named: .darkAqua)
            win.backgroundColor = .clear
            win.isOpaque = false
            win.minSize = NSSize(width: 640, height: 480)
            win.contentViewController = NSHostingController(
                rootView: ContentView(inWindow: true)
                    .environmentObject(store)
            )
            win.delegate = self
            win.center()
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing == window else { return }
        store.flushPendingSave()
        window = nil
    }

    private func createPanel() {
        let panel = TaskdownPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(store)
        )
        self.panel = panel
        applyPinnedBehavior()
    }

    private var isPinned: Bool { isPinnedSetting }

    @objc private func togglePopover() {
        if panel?.isVisible == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let panel else { return }
        NSApp.activate(ignoringOtherApps: true)
        applyPinnedBehavior()
        positionPanel()
        panel.orderFrontRegardless()
        panel.makeKey()
        updateGlobalMonitor()
    }

    private func closePopover() {
        store.flushPendingSave()
        panel?.orderOut(nil)
        removeGlobalMonitor()
    }

    private func positionPanel() {
        guard let panel, let button = statusItem.button, let buttonWindow = button.window else { return }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
        var origin = NSPoint(
            x: buttonFrameOnScreen.midX - (panelSize.width / 2),
            y: buttonFrameOnScreen.minY - panelSize.height - menuBarGap
        )

        if let screen = buttonWindow.screen ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            origin.x = max(visibleFrame.minX + 8, min(origin.x, visibleFrame.maxX - panelSize.width - 8))
            origin.y = max(visibleFrame.minY + 8, min(origin.y, visibleFrame.maxY - panelSize.height - 8))
        }

        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
    }

    private func applyPinnedBehavior() {
        panel?.level = isPinned ? .floating : .normal
        updateGlobalMonitor()
    }

    // MARK: - Monitors

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            // Cmd+W closes whichever surface is focused, with the popover's
            // proper cleanup. When a sheet is open it falls through to the store.
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
               event.charactersIgnoringModifiers?.lowercased() == "w",
               self.store.activeSheet == nil {
                if self.window?.isKeyWindow == true {
                    self.window?.performClose(nil)
                    return nil
                }
                if self.panel?.isVisible == true {
                    self.closePopover()
                    return nil
                }
            }
            return self.store.handleKeyDown(event)
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func updateGlobalMonitor() {
        removeGlobalMonitor()
        guard panel?.isVisible == true, !isPinned else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isPinned else { return }
                self.closePopover()
            }
        }
    }

    private func removeGlobalMonitor() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }
}

final class TaskdownPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
