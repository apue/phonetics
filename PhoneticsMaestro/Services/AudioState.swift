import Foundation

enum AudioState: Equatable, Sendable {
    case idle
    case recording(recordingURL: URL)
    case playing(source: AudioPlaybackSource)
    case playingABAB
}
