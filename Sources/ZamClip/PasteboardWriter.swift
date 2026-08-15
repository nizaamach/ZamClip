import AppKit
import ZamClipCore
import Foundation

enum ClipboardPayload {
    case text(String)
    case image(png: Data, tiff: Data?)

    var kind: ClipboardKind {
        switch self {
        case .text: return .text
        case .image: return .image
        }
    }

    var data: Data {
        switch self {
        case .text(let text): return Data(text.utf8)
        case .image(let png, _): return png
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
        }
    }
}
