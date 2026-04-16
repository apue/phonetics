struct TrainingCardItem: Equatable, Sendable, Identifiable {
    let kind: TrainingCardItemKind
    let itemType: String
    let itemID: Int64
    let targetID: String
    let title: String
    let subtitle: String
    let leftText: String
    let leftIPA: String?
    let rightText: String
    let rightIPA: String?
    let tierLabel: String

    var id: String { "\(itemType):\(itemID)" }
}
