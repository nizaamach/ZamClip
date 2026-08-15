import AppKit
import ZamClipCore
import SwiftUI

private final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class FloatingPanelController {
    private let panel: ClipboardPanel
    private var previousApplication: NSRunningApplication?

    init(
        store: ClipboardStore,
        settings: AppSettings,
        onCopy: @escaping (ClipboardItem) -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        panel = ClipboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Clipboard"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let view = ClipboardPanelView(
            store: store,
            settings: settings,
            onCopy: onCopy,
            onClose: { [weak self] in self?.hide() },
            onOpenSettings: onOpenSettings,
            onQuit: onQuit
        )
        panel.contentView = NSHostingView(rootView: view)
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        previousApplication = NSWorkspace.shared.frontmostApplication
        positionOnActiveScreen()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clipboardPanelWillShow, object: nil)
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    func hideAndRestorePreviousApplication(completion: @escaping () -> Void) {
        panel.orderOut(nil)
        previousApplication?.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            completion()
        }
    }

    private func positionOnActiveScreen() {
        guard let screen = NSScreen.main else {
            panel.center()
            return
        }
        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.midY - panel.frame.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}
