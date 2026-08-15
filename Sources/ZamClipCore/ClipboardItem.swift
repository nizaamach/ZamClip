import Foundation

public enum ClipboardKind: String, Codable, Sendable {
    case text
    case image
}

public struct ClipboardItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var capturedAt: Date
    public var kindRaw: String
    public var text: String?
    public var imageFilename: String?
    public var contentHash: String
    public var sourceAppName: String?
    public var sourceBundleID: String?
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        capturedAt: Date = .now,
        kind: ClipboardKind,
        text: String? = nil,
        imageFilename: String? = nil,
        contentHash: String,
        sourceAppName: String? = nil,
        sourceBundleID: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.kindRaw = kind.rawValue
        self.text = text
        self.imageFilename = imageFilename
        self.contentHash = contentHash
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.isPinned = isPinned
    }

    public var kind: ClipboardKind {
        ClipboardKind(rawValue: kindRaw) ?? .text
    }

    public var previewText: String {
        guard let text, !text.isEmpty else { return "Image" }
        return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
