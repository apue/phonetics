import Foundation

enum TrainingPlaybackControl: Equatable, Sendable {
    case targetCard(PairOption)
    case randomTest
    case practiceStandard(PairOption)
    case userRecording
    case ababLoop(PairOption)
}
