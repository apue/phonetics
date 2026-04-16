import Foundation

enum TrainingInteractionState: Equatable, Sendable {
    case idle
    case recording
    case playing(control: TrainingPlaybackControl)
}
