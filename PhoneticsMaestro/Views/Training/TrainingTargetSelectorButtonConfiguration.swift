import CoreGraphics

struct TrainingTargetSelectorButtonConfiguration: Equatable, Sendable {
    let titleText: String
    let accessorySymbolName: String
    let minimumWidth: CGFloat

    init(currentTargetTitle: String?) {
        titleText = "Target: \(currentTargetTitle ?? "Select")"
        accessorySymbolName = "chevron.down"
        minimumWidth = 220
    }
}
