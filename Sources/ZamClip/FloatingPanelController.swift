import AppKit
import ZamClipCore
import SwiftUI

private final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private static let panelSize = NSSize(width: 520, height: 420)
    private let panel: ClipboardPanel
    private var previousApplication: NSRunningApplication?
    private var isPresentingModal = false

    init(
        store: ClipboardStore,
        settings: AppSettings,
        onCopy: @escaping (ClipboardItem) -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        panel = ClipboardPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Clipboard"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        super.init()

        let view = ClipboardPanelView(
            store: store,
            settings: settings,
            onCopy: onCopy,
            onClose: { [weak self] in self?.hide() },
            onOpenSettings: onOpenSettings,
            onQuit: onQuit,
            onModalStateChange: { [weak self] isPresented in
                guard let self else { return }
                self.isPresentingModal = isPresented
                if !isPresented, self.panel.isVisible {
                    self.panel.makeKey()
                }
            }
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.delegate = self
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
        let targetFrame = frameOnActiveScreen()
        NSApp.activate(ignoringOtherApps: true)
        panel.alphaValue = 1
        panel.setFrame(targetFrame, display: false)
        panel.orderFrontRegardless()
        panel.makeKey()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clipboardPanelWillShow, object: nil)
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        panel.alphaValue = 1
        panel.setFrame(frameOnActiveScreen(), display: false)
    }

    func hideAndRestorePreviousApplication(completion: @escaping () -> Void) {
        panel.orderOut(nil)
        panel.alphaValue = 1
        previousApplication?.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            completion()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard panel.isVisible, !isPresentingModal else { return }
        hide()
    }

    private func frameOnActiveScreen() -> NSRect {
        guard let screen = NSScreen.main else {
            return panel.frame
        }
        let visibleFrame = screen.visibleFrame
        return NSRect(
            origin: NSPoint(
                x: visibleFrame.midX - Self.panelSize.width / 2,
                y: visibleFrame.midY - Self.panelSize.height / 2
            ),
            size: Self.panelSize
        )
    }
}
