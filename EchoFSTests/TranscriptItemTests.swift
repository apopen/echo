import XCTest
@testable import EchoFS

final class TranscriptItemTests: XCTestCase {

    func testTranscriptItemCreation() {
        let id = UUID()
        let now = Date()
        let item = TranscriptItem(
            id: id,
            createdAt: now,
            textRaw: "Hello world",
            textProcessed: "Hello world",
            sourceAppBundleID: "com.apple.TextEdit",
            modelID: "whisper-small.en",
            latencyMs: 500
        )

        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.textRaw, "Hello world")
        XCTAssertEqual(item.textProcessed, "Hello world")
        XCTAssertEqual(item.sourceAppBundleID, "com.apple.TextEdit")
        XCTAssertEqual(item.modelID, "whisper-small.en")
        XCTAssertEqual(item.latencyMs, 500)
    }

    func testTranscriptItemEquality() {
        let id = UUID()
        let now = Date()
        let item1 = TranscriptItem(id: id, createdAt: now, textRaw: "Hello", textProcessed: "Hello", sourceAppBundleID: nil, modelID: "whisper-small.en", latencyMs: 100)
        let item2 = TranscriptItem(id: id, createdAt: now, textRaw: "Hello", textProcessed: "Hello", sourceAppBundleID: nil, modelID: "whisper-small.en", latencyMs: 100)
        XCTAssertEqual(item1, item2)
    }

    func testTranscriptItemCodable() throws {
        let item = TranscriptItem(
            id: UUID(),
            createdAt: Date(),
            textRaw: "Test",
            textProcessed: "Test",
            sourceAppBundleID: nil,
            modelID: "whisper-small",
            latencyMs: 250
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(TranscriptItem.self, from: data)

        XCTAssertEqual(item.id, decoded.id)
        XCTAssertEqual(item.textRaw, decoded.textRaw)
        XCTAssertEqual(item.modelID, decoded.modelID)
    }
}
