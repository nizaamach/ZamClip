import AppKit
import Combine
import CryptoKit
import Foundation

@MainActor
public final class ClipboardStore: ObservableObject {
    @Published public private(set) var items: [ClipboardItem] = []
    @Published public private(set) var lastError: String?

    public private(set) var historyLimit: Int
    public let storageDirectory: URL
    public let imagesDirectory: URL

    private let historyURL: URL

    public init(historyLimit: Int = 500) {
        self.historyLimit = max(1, historyLimit)

        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let root = applicationSupport.appendingPathComponent("ZamClip", isDirectory: true)
        let images = root.appendingPathComponent("Images", isDirectory: true)
        self.storageDirectory = root
        self.imagesDirectory = images
        self.historyURL = root.appendingPathComponent("history.json")

        do {
            try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        } catch {
            self.lastError = "Unable to prepare image storage."
        }

        items = Self.loadItems(from: historyURL)
        enforceRetention()
        persist()
    }

    public func updateHistoryLimit(_ limit: Int) {
        historyLimit = max(1, limit)
        enforceRetention()
        persist()
    }

    @discardableResult
    public func captureText(
        _ text: String,
        sourceAppName: String?,
        sourceBundleID: String?
    ) -> ClipboardItem? {
        guard !text.isEmpty else { return nil }

        let data = Data(text.utf8)
        let hash = Self.contentHash(kind: .text, data: data)
        if let index = items.firstIndex(where: { $0.contentHash == hash }) {
            var existing = items[index]
            existing.capturedAt = .now
            existing.sourceAppName = sourceAppName
            existing.sourceBundleID = sourceBundleID
            items.remove(at: index)
            items.insert(existing, at: 0)
            persist()
            return existing
        }

        let item = ClipboardItem(
            kind: .text,
            text: text,
            contentHash: hash,
            sourceAppName: sourceAppName,
            sourceBundleID: sourceBundleID
        )
        items.insert(item, at: 0)
        enforceRetention()
        persist()
        return item
    }

    @discardableResult
    public func captureImage(
        _ data: Data,
        sourceAppName: String?,
        sourceBundleID: String?
    ) -> ClipboardItem? {
        guard NSImage(data: data) != nil else { return nil }

        let hash = Self.contentHash(kind: .image, data: data)
        if let index = items.firstIndex(where: { $0.contentHash == hash }) {
            var existing = items[index]
            existing.capturedAt = .now
            existing.sourceAppName = sourceAppName
            existing.sourceBundleID = sourceBundleID
            items.remove(at: index)
            items.insert(existing, at: 0)
            persist()
            return existing
        }

        let filename = "\(UUID().uuidString).png"
        let imageURL = imagesDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: imageURL, options: .atomic)
        } catch {
            lastError = "Unable to save clipboard image."
            return nil
        }

        let item = ClipboardItem(
            kind: .image,
            imageFilename: filename,
            contentHash: hash,
            sourceAppName: sourceAppName,
            sourceBundleID: sourceBundleID
        )
        items.insert(item, at: 0)
        enforceRetention()
        persist()
        return item
    }

    public func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        persist()
    }

    public func delete(_ item: ClipboardItem) {
        if let filename = item.imageFilename {
            try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(filename))
        }
        items.removeAll { $0.id == item.id }
        persist()
    }

    public func clearUnpinned() {
        let removed = items.filter { !$0.isPinned }
        removed.forEach { removeImageFile(for: $0) }
        items.removeAll { !$0.isPinned }
        persist()
    }

    public func clearAll() {
        items.forEach { removeImageFile(for: $0) }
        items.removeAll()
        persist()
    }

    public func imageURL(for item: ClipboardItem) -> URL? {
        guard let filename = item.imageFilename else { return nil }
        return imagesDirectory.appendingPathComponent(filename)
    }

    public static func contentHash(kind: ClipboardKind, data: Data) -> String {
        var input = Data(kind.rawValue.utf8)
        input.append(0)
        input.append(data)
        return SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
    }

    private func enforceRetention() {
        let ordinaryItems = items
            .filter { !$0.isPinned }
            .sorted { $0.capturedAt > $1.capturedAt }
        guard ordinaryItems.count > historyLimit else { return }

        let removed = ordinaryItems.dropFirst(historyLimit)
        removed.forEach { removeImageFile(for: $0) }
        let removedIDs = Set(removed.map(\.id))
        items.removeAll { removedIDs.contains($0.id) }
    }

    private func removeImageFile(for item: ClipboardItem) {
        guard let filename = item.imageFilename else { return }
        try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(filename))
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: historyURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Unable to save clipboard history."
        }
    }

    private static func loadItems(from url: URL) -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ClipboardItem].self, from: data)
        } catch {
            return []
        }
    }
}
