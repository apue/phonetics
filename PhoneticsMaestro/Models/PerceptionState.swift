enum PerceptionState: Equatable, Sendable {
    case idle
    case awaitingAnswer
    case correct(expected: PairOption)
    case incorrect(expected: PairOption)
}
