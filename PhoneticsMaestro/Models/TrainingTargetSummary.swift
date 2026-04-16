struct TrainingTargetSummary: Equatable, Sendable, Identifiable {
    let id: String
    let group: TrainingTargetGroup
    let title: String
    let subtitle: String
    let currentItemType: String

    var displayLabel: String { title }
}
