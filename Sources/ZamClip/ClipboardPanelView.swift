import AppKit
import Carbon.HIToolbox
import ZamClipCore
import SwiftUI

extension Notification.Name {
    static let clipboardPanelWillShow = Notification.Name("ClipboardPanelWillShow")
}

private enum ClipboardFilter: String, CaseIterable {
    case all
    case pinned

    var title: String {
        switch self {
        case .all: return "All"
        case .pinned: return "Pinned"
        }
    }
}

struct ClipboardPanelView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var settings: AppSettings

    let onCopy: (ClipboardItem) -> Void
    let onClose: () -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    @State private var filter: ClipboardFilter = .all
    @State private var selectedItemID: ClipboardItem.ID?
    @State private var showingClearConfirmation = false

    private var visibleItems: [ClipboardItem] {
        switch filter {
        case .all:
            return store.items
        case .pinned:
            return store.items.filter(\.isPinned)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 28, y: 12)

            VStack(spacing: 0) {
                header
                Divider()
                    .opacity(0.18)
                    .padding(.horizontal, 14)
                filterPicker
                content
            }
            .padding(12)
        }
        .frame(width: 360, height: 480)
        .overlay {
            KeyboardCaptureView { event in
                handleKeyPress(event)
            }
            .frame(width: 1, height: 1)
            .opacity(0.01)
        }
        .onAppear {
            selectedItemID = visibleItems.first?.id
        }
        .onChange(of: filter) { _, _ in
            selectedItemID = visibleItems.first?.id
        }
        .onExitCommand {
            onClose()
        }
        .alert("Clear unpinned items?", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) {
                store.clearUnpinned()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pinned items will remain.")
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "square.on.square")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.85))

            Text("Clipboard")
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.72))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .help("Close")

            Menu {
                Button("Settings", action: onOpenSettings)
                Button("Clear Unpinned") {
                    showingClearConfirmation = true
                }
                Divider()
                Button("Quit", role: .destructive, action: onQuit)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.72))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("More actions")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            ForEach(ClipboardFilter.allCases, id: \.self) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
    }

    private var content: some View {
        Group {
            if visibleItems.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: filter == .pinned ? "pin.slash" : "square.on.square")
                        .font(.system(size: 27, weight: .light))
                        .foregroundStyle(.secondary)
                    Text(filter == .pinned ? "No pinned items" : "Copy something to start")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach(visibleItems, id: \.id) { item in
                                ClipboardRow(
                                    item: item,
                                    imageURL: store.imageURL(for: item),
                                    isSelected: selectedItemID == item.id
                                )
                                    .id(item.id)
                                    .onTapGesture {
                                        selectedItemID = item.id
                                        onCopy(item)
                                    }
                                    .contextMenu {
                                        Button("Copy") { onCopy(item) }
                                        Button(item.isPinned ? "Unpin" : "Pin") {
                                            store.togglePin(item)
                                        }
                                        Divider()
                                        Button("Delete", role: .destructive) {
                                            store.delete(item)
                                        }
                                    }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityHint("Copies this item")
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                    .onReceive(NotificationCenter.default.publisher(for: .clipboardPanelWillShow)) { _ in
                        selectedItemID = visibleItems.first?.id
                        if let firstID = visibleItems.first?.id {
                            proxy.scrollTo(firstID, anchor: .top)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func moveSelection(by offset: Int) {
        guard !visibleItems.isEmpty else { return }

        guard let selectedItemID,
              let currentIndex = visibleItems.firstIndex(where: { $0.id == selectedItemID }) else {
            self.selectedItemID = visibleItems.first?.id
            return
        }

        let nextIndex = min(
            max(currentIndex + offset, 0),
            visibleItems.count - 1
        )
        self.selectedItemID = visibleItems[nextIndex].id
    }

    private func activateSelectedItem() {
        guard let selectedItemID,
              let item = visibleItems.first(where: { $0.id == selectedItemID }) else { return }
        onCopy(item)
    }

    private func handleKeyPress(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case UInt16(kVK_UpArrow):
            moveSelection(by: -1)
        case UInt16(kVK_DownArrow):
            moveSelection(by: 1)
        case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
            activateSelectedItem()
        case UInt16(kVK_Escape):
            onClose()
        default:
            return false
        }
        return true
    }
}

private struct KeyboardCaptureView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyboardCaptureNSView {
        let view = KeyboardCaptureNSView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyboardCaptureNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }
}

private final class KeyboardCaptureNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard onKeyDown?(event) == true else {
            super.keyDown(with: event)
            return
        }
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let imageURL: URL?
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        Group {
            switch item.kind {
            case .text:
                textRow
            case .image:
                imageRow
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.22)
                        : Color.white.opacity(isHovered ? 0.16 : 0.08)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(
                            isSelected
                                ? Color.accentColor.opacity(0.55)
                                : Color.white.opacity(isHovered ? 0.18 : 0.08),
                            lineWidth: 1
                        )
                }
        }
        .onHover { isHovered = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var textRow: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isPinned ? "pin.fill" : "doc.text")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(item.isPinned ? Color.orange : Color.primary.opacity(0.55))
                .frame(width: 19)

            Text(item.previewText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .frame(height: 52)
        .padding(.horizontal, 12)
        .accessibilityLabel(item.previewText)
    }

    private var imageRow: some View {
        HStack(spacing: 12) {
            thumbnail
            Spacer(minLength: 0)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.trailing, 12)
            }
        }
        .frame(height: 84)
        .padding(.leading, 6)
        .accessibilityLabel(item.isPinned ? "Pinned image" : "Image")
    }

    private var thumbnail: some View {
        Group {
            if let imageURL, let image = NSImage(contentsOf: imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
        .background(Color.black.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }
}
