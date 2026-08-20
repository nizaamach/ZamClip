import AppKit
import Carbon.HIToolbox
import ZamClipCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchManager: LaunchManager
    @ObservedObject var store: ClipboardStore
    let onShortcutChange: () -> Void

    @State private var newBundleID = ""
    @State private var showingClearConfirmation = false
    @State private var isRecordingShortcut = false

    var body: some View {
        Form {
            Section("General") {
                Toggle(
                    "Start at login",
                    isOn: Binding(
                        get: { launchManager.isEnabled },
                        set: { launchManager.setEnabled($0) }
                    )
                )

                HStack {
                    Text("Global shortcut")
                    Spacer()
                    Button(isRecordingShortcut ? "Press keys..." : settings.shortcutDisplay) {
                        isRecordingShortcut = true
                    }
                    .buttonStyle(.bordered)
                }

                if isRecordingShortcut {
                    Text("Press a key with Command, Shift, Option, or Control.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ShortcutRecorder(
                    isRecording: $isRecordingShortcut,
                    onShortcut: { keyCode, modifiers, label in
                        settings.setGlobalShortcut(
                            keyCode: keyCode,
                            modifiers: modifiers,
                            keyLabel: label
                        )
                        isRecordingShortcut = false
                        onShortcutChange()
                    },
                    onCancel: {
                        isRecordingShortcut = false
                    }
                )
                .frame(width: 1, height: 1)
                .opacity(0.01)

                Picker(
                    "History limit",
                    selection: Binding(
                        get: { settings.historyLimit },
                        set: {
                            settings.historyLimit = $0
                            store.updateHistoryLimit($0)
                        }
                    )
                ) {
                    Text("100 items").tag(100)
                    Text("500 items").tag(500)
                    Text("1,000 items").tag(1000)
                    Text("2,000 items").tag(2000)
                }
            }

            Section("Privacy") {
                Toggle("Ignore unknown source apps", isOn: $settings.ignoreUnknownSources)

                HStack {
                    TextField("Bundle ID", text: $newBundleID)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        settings.addExcludedBundleID(newBundleID)
                        newBundleID = ""
                    }
                    .disabled(newBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                List {
                    ForEach(settings.excludedBundleIDs, id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                settings.removeExcludedBundleID(bundleID)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .frame(minHeight: 90, maxHeight: 130)
            }

            Section("Storage") {
                Button("Clear Unpinned Items", role: .destructive) {
                    showingClearConfirmation = true
                }
            }

            if let error = launchManager.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
        .formStyle(.grouped)
        .padding(18)
        .frame(width: 500, height: 470)
        .alert("Clear unpinned items?", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) { store.clearUnpinned() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pinned items will remain.")
        }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onShortcut: (UInt32, UInt32, String) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.isRecording = isRecording
        view.onShortcut = onShortcut
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.isRecording = isRecording
        nsView.onShortcut = onShortcut
        nsView.onCancel = onCancel
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class ShortcutRecorderNSView: NSView {
    var isRecording = false
    var onShortcut: ((UInt32, UInt32, String) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if isRecording {
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        let modifiers = GlobalHotKey.carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else {
            NSSound.beep()
            return
        }

        onShortcut?(UInt32(event.keyCode), modifiers, GlobalHotKey.keyLabel(for: event))
    }
}
