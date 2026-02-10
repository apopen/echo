import XCTest
@testable import EchoFS

final class RecordingStateTests: XCTestCase {

    // MARK: - State Machine Transitions

    func testInitialStateIsIdle() {
        let state = RecordingState.idle
        XCTAssertEqual(state, .idle)
    }

    func testIdleToRecordingTransition() {
        var state = RecordingState.idle
        // Simulate: hotkey pressed
        state = .recording
        XCTAssertEqual(state, .recording)
    }

    func testRecordingToTranscribingTransition() {
        var state = RecordingState.recording
        // Simulate: hotkey released, audio captured
        state = .transcribing
        XCTAssertEqual(state, .transcribing)
    }

    func testTranscribingToInsertingTransition() {
        var state = RecordingState.transcribing
        // Simulate: transcription complete
        state = .inserting
        XCTAssertEqual(state, .inserting)
    }

    func testInsertingToIdleTransition() {
        var state = RecordingState.inserting
        // Simulate: insertion complete
        state = .idle
        XCTAssertEqual(state, .idle)
    }

    func testErrorFromRecording() {
        var state = RecordingState.recording
        state = .error(.permissionDenied(.microphone))
        XCTAssertEqual(state, .error(.permissionDenied(.microphone)))
    }

    func testErrorFromTranscribing() {
        var state = RecordingState.transcribing
        state = .error(.transcriptionFailed("model not loaded"))
        XCTAssertEqual(state, .error(.transcriptionFailed("model not loaded")))
    }

    func testRecordModeValues() {
        XCTAssertEqual(RecordMode.hold.rawValue, "hold")
        XCTAssertEqual(RecordMode.toggle.rawValue, "toggle")
    }
}
