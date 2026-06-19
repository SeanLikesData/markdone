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
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBarGap: CGFloat = 1
    private let panelSize = NSSize(width: 780, height: 660)
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store = WeekStore()
    private let logger = Logger(subsystem: "com.taskdown.app", category: "popover")

    private var panel: TaskdownPanel?
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

        installMainMenu()
        createPanel()

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

        NSApp.mainMenu = mainMenu
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
        installKeyMonitor()
        updateGlobalMonitor()
    }

    private func closePopover() {
        store.flushPendingSave()
        panel?.orderOut(nil)
        removeGlobalMonitor()
        removeKeyMonitor()
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
