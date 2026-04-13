import Foundation

enum AudioServiceError: LocalizedError, Equatable {
    case illegalTransition(currentState: AudioState, attemptedAction: String)
    case microphonePermissionDenied
    case missingRecording
    case invalidRandomTestOptions
    case playbackFailed(String)
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case let .illegalTransition(currentState, attemptedAction):
            return "Illegal transition from \(currentState) via \(attemptedAction)."
        case .microphonePermissionDenied:
            return "Microphone permission was denied."
        case .missingRecording:
            return "No user recording is available."
        case .invalidRandomTestOptions:
            return "Random test requires at least two options."
        case let .playbackFailed(message):
            return "Playback failed: \(message)"
        case let .recordingFailed(message):
            return "Recording failed: \(message)"
        }
    }
}
