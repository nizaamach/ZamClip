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

private enum FileCategory: Hashable {
    case folder
    case image
    case video
    case audio
    case document
    case spreadsheet
    case presentation
    case archive
    case code
    case font
    case design
    case mixed
    case generic

    var symbolName: String {
        switch self {
        case .folder: return "folder.fill"
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "music.note"
        case .document: return "doc.text"
        case .spreadsheet: return "tablecells"
        case .presentation: return "rectangle.3.group"
        case .archive: return "archivebox"
        case .code: return "curlybraces"
        case .font: return "textformat"
        case .design: return "paintpalette"
        case .mixed: return "square.grid.2x2"
        case .generic: return "doc"
        }
    }

    var tint: Color {
        switch self {
        case .folder: return .blue
        case .image: return .purple
        case .video: return .indigo
        case .audio: return .pink
        case .document: return .red
        case .spreadsheet: return .green
        case .presentation: return .orange
        case .archive: return .brown
        case .code: return .teal
        case .font: return .mint
        case .design: return .cyan
        case .mixed, .generic: return .secondary
        }
    }

    static func category(for urls: [URL]) -> FileCategory {
        let categories = Set(urls.map(category(for:)))
        guard categories.count == 1, let category = categories.first else {
            return categories.isEmpty ? .generic : .mixed
        }
        return category
    }

    private static func category(for url: URL) -> FileCategory {
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
           values.isDirectory == true {
            return .folder
        }

        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "tif", "tiff", "bmp", "svg":
            return .image
        case "mov", "mp4", "m4v", "avi", "mkv", "webm":
            return .video
        case "mp3", "m4a", "wav", "aiff", "flac", "ogg", "caf":
            return .audio
        case "xls", "xlsx", "csv", "tsv", "numbers":
            return .spreadsheet
        case "ppt", "pptx", "key":
            return .presentation
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar", "dmg", "pkg", "iso":
            return .archive
        case "swift", "m", "h", "mm", "c", "cpp", "cc", "hpp", "rs", "go", "py", "js", "jsx", "ts", "tsx", "java", "kt", "kts", "rb", "php", "sh", "zsh", "bash", "json", "yaml", "yml", "xml", "html", "css", "scss", "sql":
            return .code
        case "ttf", "otf", "woff", "woff2":
            return .font
        case "psd", "ai", "sketch", "fig", "figma":
            return .design
        case "pdf", "doc", "docx", "pages", "rtf", "txt", "md":
            return .document
        default:
            return .generic
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
    let onModalStateChange: (Bool) -> Void

    @State private var filter: ClipboardFilter = .all
    @State private var selectedItemID: ClipboardItem.ID?
    @State private var showingClearConfirmation = false
    @State private var searchText = ""
    @FocusState private var searchFieldFocused: Bool

    private var visibleItems: [ClipboardItem] {
        let filteredItems: [ClipboardItem]
        switch filter {
        case .all:
            filteredItems = store.items
        case .pinned:
            filteredItems = store.items.filter(\.isPinned)
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return filteredItems }

        return filteredItems.filter { item in
            item.text?.localizedCaseInsensitiveContains(query) == true
                || item.previewText.localizedCaseInsensitiveContains(query)
                || item.filePaths?.contains { $0.localizedCaseInsensitiveContains(query) } == true
                || item.sourceAppName?.localizedCaseInsensitiveContains(query) == true
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.24), radius: 24, y: 12)

            VStack(spacing: 0) {
                searchField
                filterPicker
                content
                keyboardHints
            }
            .padding(10)
        }
        .frame(width: 520, height: 420)
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
        .onChange(of: searchText) { _, _ in
            selectedItemID = visibleItems.first?.id
        }
        .onChange(of: showingClearConfirmation) { _, isPresented in
            onModalStateChange(isPresented)
        }
        .onExitCommand {
            onClose()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardPanelWillShow)) { _ in
            searchText = ""
            filter = .all
            selectedItemID = store.items.first?.id
            DispatchQueue.main.async {
                searchFieldFocused = true
            }
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

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search clipboard", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .regular))
                .focused($searchFieldFocused)
                .onSubmit {
                    activateSelectedItem()
                }

            if searchText.isEmpty {
                Text("Cmd F")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            } else {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            Menu {
                Button("Settings", action: onOpenSettings)
                Button("Clear Unpinned") {
                    showingClearConfirmation = true
                }
                Divider()
                Button("Quit", role: .destructive, action: onQuit)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("More actions")
        }
        .padding(.horizontal, 13)
        .frame(height: 50)
        .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    searchFieldFocused ? Color.accentColor.opacity(0.7) : Color.white.opacity(0.14),
                    lineWidth: 1
                )
        }
        .padding(.horizontal, 4)
        .padding(.top, 3)
    }

    private var filterPicker: some View {
        HStack(spacing: 4) {
            ForEach(ClipboardFilter.allCases, id: \.self) { item in
                Button {
                    filter = item
                } label: {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(filter == item ? .primary : .secondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(
                            filter == item ? Color.primary.opacity(0.12) : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("\(visibleItems.count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 7)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var content: some View {
        Group {
            if visibleItems.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: emptyStateIcon)
                        .font(.system(size: 27, weight: .light))
                        .foregroundStyle(.secondary)
                    Text(emptyStateTitle)
                        .font(.system(size: 13, weight: .medium))
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
                                    isSelected: selectedItemID == item.id,
                                    onTogglePin: { store.togglePin(item) }
                                )
                                    .id(item.id)
                                    .highPriorityGesture(
                                        TapGesture(count: 2).onEnded {
                                            selectedItemID = item.id
                                            onCopy(item)
                                        }
                                    )
                                    .onTapGesture {
                                        selectedItemID = item.id
                                    }
                                    .contextMenu {
                                        Button("Paste") { onCopy(item) }
                                        Button(item.isPinned ? "Unpin" : "Pin") {
                                            store.togglePin(item)
                                        }
                                        Divider()
                                        Button("Delete", role: .destructive) {
                                            store.delete(item)
                                        }
                                    }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityHint("Selects this item. Double-click or press Enter to paste.")
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: selectedItemID) { _, newID in
                        guard let newID else { return }
                        proxy.scrollTo(newID, anchor: .center)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .clipboardPanelWillShow)) { _ in
                        selectedItemID = visibleItems.first?.id
                        if let firstID = visibleItems.first?.id {
                            proxy.scrollTo(firstID, anchor: .top)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var keyboardHints: some View {
        HStack(spacing: 12) {
            Text("Up/Down Navigate")
            Text("Enter Paste")
            Text("Double-click Paste")
            Spacer()
            Text("Esc Close")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 9)
        .padding(.top, 7)
        .padding(.bottom, 2)
    }

    private var emptyStateIcon: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "magnifyingglass"
        }
        return filter == .pinned ? "pin.slash" : "square.on.square"
    }

    private var emptyStateTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No matching items"
        }
        return filter == .pinned ? "No pinned items" : "Copy something to start"
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
        if event.modifierFlags.contains(.command), event.keyCode == UInt16(kVK_ANSI_F) {
            searchFieldFocused = true
            return true
        }

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
    private var eventMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeEventMonitor()
        guard window != nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.isVisible == true, self.onKeyDown?(event) == true else {
                return event
            }
            return nil
        }
    }

    deinit {
        removeEventMonitor()
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
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
    let onTogglePin: () -> Void
    @State private var isHovered = false

    var body: some View {
        Group {
            switch item.kind {
            case .text:
                textRow
            case .image:
                imageRow
            case .files:
                fileRow
            }
        }
        .padding(.trailing, 38)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.18)
                        : Color.white.opacity(isHovered ? 0.08 : 0.02)
                )
        }
        .overlay(alignment: .trailing) {
            pinButton
                .padding(.trailing, 6)
        }
        .onHover { isHovered = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var textRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.55))
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.previewText)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(metadataText)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

        }
        .frame(height: 54)
        .padding(.horizontal, 12)
        .accessibilityLabel(item.previewText)
    }

    private var imageRow: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text("Image")
                    .font(.system(size: 13, weight: .regular))

                Text(metadataText)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

        }
        .frame(height: 58)
        .padding(.horizontal, 8)
        .accessibilityLabel(item.isPinned ? "Pinned image" : "Image")
    }

    private var fileRow: some View {
        HStack(spacing: 10) {
            fileIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(item.fileSummary)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(fileMetadataText)
                    if item.missingFileCount > 0 {
                        Text("\(item.missingFileCount) missing")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

        }
        .frame(minHeight: 58)
        .padding(.horizontal, 12)
        .accessibilityLabel(item.fileSummary)
    }

    private var fileCount: Int {
        item.filePaths?.count ?? 0
    }

    private var fileCategory: FileCategory {
        FileCategory.category(for: item.fileURLs)
    }

    private var pinButton: some View {
        Button(action: onTogglePin) {
            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(item.isPinned ? Color.orange : Color.secondary.opacity(0.75))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.isPinned ? "Unpin" : "Pin")
        .help(item.isPinned ? "Unpin" : "Pin")
    }

    @ViewBuilder
    private var fileIcon: some View {
        if let image = fileThumbnail {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        } else {
            Image(systemName: fileCategory.symbolName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(fileCategory.tint)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var fileThumbnail: NSImage? {
        guard fileCount == 1,
              let url = item.fileURLs.first,
              isImageFile(url),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return NSImage(data: data)
    }

    private func isImageFile(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "gif", "webp", "heic", "tif", "tiff"].contains(url.pathExtension.lowercased())
    }

    private var metadataText: String {
        let source = item.sourceAppName ?? "Unknown app"
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let time = formatter.localizedString(for: item.capturedAt, relativeTo: .now)
        return "\(source) - \(time)"
    }

    private var fileMetadataText: String {
        let count = fileCount == 1 ? "1 file" : "\(fileCount) files"
        return "\(count) - \(metadataText)"
    }

    private var thumbnail: some View {
        Group {
            if let imageURL,
               let data = try? Data(contentsOf: imageURL),
               let image = NSImage(data: data) {
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
        .frame(width: 42, height: 42)
        .background(Color.black.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
