enum TrainingCardItemKind: Equatable, Sendable {
    case pair
    case sentence(phenomenon: String)

    var itemType: String {
        switch self {
        case .pair:
            "pair"
        case .sentence:
            "sentence"
        }
    }
}
