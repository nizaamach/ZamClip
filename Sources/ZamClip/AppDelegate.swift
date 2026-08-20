import AppKit
import ZamClipCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var store: ClipboardStore!
    private var settings: AppSettings!
    private var monitor: ClipboardMonitor!
    private var writer = PasteboardWriter()
    private var launchManager: LaunchManager!
    private var panelController: FloatingPanelController!
    private var settingsWindow: NSWindow?
    private var globalHotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        settings = AppSettings()
        store = ClipboardStore(historyLimit: settings.historyLimit)
        launchManager = LaunchManager()

        monitor = ClipboardMonitor(
            store: store,
            sourceProvider: {
                let app = NSWorkspace.shared.frontmostApplication
                return (app?.localizedName, app?.bundleIdentifier)
            },
            exclusionProvider: { [weak self] bundleID in
                self?.settings.isExcluded(bundleID: bundleID) ?? false
            }
        )
        monitor.start()

        configureStatusItem()

        panelController = FloatingPanelController(
            store: store,
            settings: settings,
            onCopy: { [weak self] item in self?.copy(item) },
            onOpenSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) }
        )

        configureGlobalHotKey()

        DispatchQueue.main.async { [weak self] in
            self?.panelController.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard.fill",
            accessibilityDescription: "ZamClip"
        )
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.title = " Clip"
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)
        updateStatusItemShortcut()
    }

    private func updateStatusItemShortcut() {
        statusItem.button?.toolTip = "ZamClip (\(settings.shortcutDisplay))"
    }

    private func configureGlobalHotKey() {
        globalHotKey = nil

        do {
            globalHotKey = try GlobalHotKey(
                keyCode: settings.hotKeyKeyCode,
                modifiers: settings.hotKeyModifiers
            ) { [weak self] in
                Task { @MainActor in
                    self?.panelController.toggle()
                }
            }
            updateStatusItemShortcut()
        } catch {
            NSLog("ZamClip could not register the global shortcut: \(error)")
        }
    }

    private func copy(_ item: ClipboardItem) {
        guard let payload = writer.payload(for: item, store: store) else { return }
        guard PasteSender.hasAccessibilityAccess else {
            showAccessibilityAlert()
            return
        }
        monitor.ignoreNext(kind: payload.kind, data: payload.data)
        writer.write(payload)
        panelController.hideAndRestorePreviousApplication {
            guard PasteSender.sendPaste() else {
                self.showAccessibilityAlert()
                return
            }
        }
    }

    private func showAccessibilityAlert() {
        PasteSender.requestAccessibilityAccess()
        let alert = NSAlert()
        alert.messageText = "Accessibility access is required"
        alert.informativeText = "Remove any old ZamClip entry, add this current app from dist/ZamClip.app, then relaunch it."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 470),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ZamClip Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: SettingsView(
                settings: settings,
                launchManager: launchManager,
                store: store,
                onShortcutChange: { [weak self] in
                    self?.configureGlobalHotKey()
                }
            )
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }
}
