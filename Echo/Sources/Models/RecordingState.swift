import Foundation

/// Deterministic state machine for the dictation pipeline.
enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case inserting
    case error(RecordingError)

    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording),
             (.transcribing, .transcribing), (.inserting, .inserting):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

enum RecordingError: Equatable {
    case permissionDenied(PermissionType)
    case transcriptionFailed(String)
    case insertionFailed(String)
    case maxDurationReached
}

enum PermissionType: String, Equatable {
    case microphone
    case accessibility
}

enum RecordMode: String, Codable {
    case hold
    case toggle
}

enum InsertionMode: String, Codable {
    case copyToClipboard
    case pasteInPlace
}
