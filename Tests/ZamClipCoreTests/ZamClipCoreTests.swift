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

    func testFileItemSummarizesMultipleFiles() {
        let item = ClipboardItem(
            kind: .files,
            filePaths: ["/tmp/one.txt", "/tmp/two.txt", "/tmp/three.txt"],
            contentHash: "hash"
        )

        XCTAssertEqual(item.fileSummary, "one.txt, two.txt + 1 more")
        XCTAssertEqual(item.previewText, item.fileSummary)
    }

    func testFileReferenceHashIgnoresSelectionOrder() {
        let first = [URL(fileURLWithPath: "/tmp/one.txt"), URL(fileURLWithPath: "/tmp/two.txt")]
        let second = [URL(fileURLWithPath: "/tmp/two.txt"), URL(fileURLWithPath: "/tmp/one.txt")]

        XCTAssertEqual(
            ClipboardStore.contentHash(kind: .files, data: ClipboardStore.fileReferenceData(first)),
            ClipboardStore.contentHash(kind: .files, data: ClipboardStore.fileReferenceData(second))
        )
    }
}
