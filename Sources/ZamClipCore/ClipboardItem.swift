import Foundation

public enum ClipboardKind: String, Codable, Sendable {
    case text
    case image
    case files
}

public struct ClipboardItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var capturedAt: Date
    public var kindRaw: String
    public var text: String?
    public var imageFilename: String?
    public var filePaths: [String]?
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
        filePaths: [String]? = nil,
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
        self.filePaths = filePaths
        self.contentHash = contentHash
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.isPinned = isPinned
    }

    public var kind: ClipboardKind {
        ClipboardKind(rawValue: kindRaw) ?? .text
    }

    public var fileURLs: [URL] {
        (filePaths ?? []).map { URL(fileURLWithPath: $0) }
    }

    public var fileNames: [String] {
        fileURLs.map(\.lastPathComponent)
    }

    public var missingFileCount: Int {
        fileURLs.filter { !FileManager.default.fileExists(atPath: $0.path) }.count
    }

    public var fileSummary: String {
        let names = fileNames
        guard !names.isEmpty else { return "Files" }
        guard names.count > 2 else { return names.joined(separator: ", ") }
        return "\(names[0]), \(names[1]) + \(names.count - 2) more"
    }

    public var previewText: String {
        switch kind {
        case .text:
            guard let text, !text.isEmpty else { return "Text" }
            return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        case .image:
            return "Image"
        case .files:
            return fileSummary
        }
    }
}
