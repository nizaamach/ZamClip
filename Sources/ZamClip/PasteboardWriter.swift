import AppKit
import ZamClipCore
import Foundation

enum ClipboardPayload {
    case text(String)
    case image(png: Data, tiff: Data?)
    case files([URL])

    var kind: ClipboardKind {
        switch self {
        case .text: return .text
        case .image: return .image
        case .files: return .files
        }
    }

    var data: Data {
        switch self {
        case .text(let text): return Data(text.utf8)
        case .image(let png, _): return png
        case .files(let urls): return ClipboardStore.fileReferenceData(urls)
        }
    }
}

@MainActor
final class PasteboardWriter {
    func payload(for item: ClipboardItem, store: ClipboardStore) -> ClipboardPayload? {
        switch item.kind {
        case .text:
            guard let text = item.text else { return nil }
            return .text(text)
        case .image:
            guard let url = store.imageURL(for: item),
                  let pngData = try? Data(contentsOf: url),
                  let image = NSImage(data: pngData) else { return nil }
            return .image(png: pngData, tiff: image.tiffRepresentation)
        case .files:
            guard let paths = item.filePaths, !paths.isEmpty else { return nil }
            return .files(paths.map { URL(fileURLWithPath: $0) })
        }
    }

    func write(_ payload: ClipboardPayload) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch payload {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let png, let tiff):
            pasteboard.setData(png, forType: .png)
            if let tiff {
                pasteboard.setData(tiff, forType: .tiff)
            }
        case .files(let urls):
            _ = pasteboard.writeObjects(urls.map { $0 as NSURL })
        }
    }
}
