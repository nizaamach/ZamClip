import XCTest
@testable import ZamClipCore

final class ZamClipCoreTests: XCTestCase {
    func testTextHashIsStable() {
        let data = Data("hello".utf8)

        XCTAssertEqual(
            ClipboardStore.contentHash(kind: .text, data: data),
            ClipboardStore.contentHash(kind: .text, data: data)
        )
    }

    func testTextAndImageHashesDoNotOverlap() {
        let data = Data("same bytes".utf8)

        XCTAssertNotEqual(
            ClipboardStore.contentHash(kind: .text, data: data),
            ClipboardStore.contentHash(kind: .image, data: data)
        )
    }

    func testPreviewCollapsesWhitespace() {
        let item = ClipboardItem(
            kind: .text,
            text: "hello\nworld",
            contentHash: "hash"
        )

        XCTAssertEqual(item.previewText, "hello world")
    }
}
