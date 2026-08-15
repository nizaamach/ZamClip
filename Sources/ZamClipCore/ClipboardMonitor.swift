import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
public final class ClipboardMonitor {
    public typealias SourceProvider = () -> (name: String?, bundleID: String?)
    public typealias ExclusionProvider = (String?) -> Bool

    private let pasteboard = NSPasteboard.general
    private let store: ClipboardStore
    private let sourceProvider: SourceProvider
    private let exclusionProvider: ExclusionProvider
    private var timer: Timer?
    private var lastChangeCount: Int
    private var ignoredHashes: Set<String> = []

    public init(
        store: ClipboardStore,
        sourceProvider: @escaping SourceProvider,
        exclusionProvider: @escaping ExclusionProvider
    ) {
        self.store = store
        self.sourceProvider = sourceProvider
        self.exclusionProvider = exclusionProvider
        self.lastChangeCount = pasteboard.changeCount
    }

    public func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func ignoreNext(kind: ClipboardKind, data: Data) {
        ignoredHashes.insert(ClipboardStore.contentHash(kind: kind, data: data))
    }

    private func poll() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        let source = sourceProvider()
        guard !exclusionProvider(source.bundleID) else { return }

        let fileURLs = fileURLsOnPasteboard()
        if !fileURLs.isEmpty {
            let data = ClipboardStore.fileReferenceData(fileURLs)
            if ignoredHashes.remove(ClipboardStore.contentHash(kind: .files, data: data)) != nil {
                return
            }
            store.captureFiles(fileURLs, sourceAppName: source.name, sourceBundleID: source.bundleID)
            return
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let data = Data(text.utf8)
            let hash = ClipboardStore.contentHash(kind: .text, data: data)
            if ignoredHashes.remove(hash) != nil { return }
            store.captureText(text, sourceAppName: source.name, sourceBundleID: source.bundleID)
            return
        }

        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
        for type in imageTypes {
            guard let rawData = pasteboard.data(forType: type) else { continue }
            guard let image = NSImage(data: rawData), let normalizedData = image.pngData else { continue }
            let hash = ClipboardStore.contentHash(kind: .image, data: normalizedData)
            if ignoredHashes.remove(hash) != nil { return }
            store.captureImage(normalizedData, sourceAppName: source.name, sourceBundleID: source.bundleID)
            return
        }
    }

    private func fileURLsOnPasteboard() -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) ?? []

        return objects.compactMap { object in
            if let url = object as? URL, url.isFileURL {
                return url
            }
            guard let url = object as? NSURL,
                  url.isFileURL,
                  let path = url.path else { return nil }
            return URL(fileURLWithPath: path)
        }
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
