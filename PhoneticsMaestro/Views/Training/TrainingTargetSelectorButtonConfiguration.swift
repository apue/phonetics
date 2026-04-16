import CoreGraphics

struct TrainingTargetSelectorButtonConfiguration: Equatable, Sendable {
    let titleText: String
    let accessorySymbolName: String
    let fixedWidth: CGFloat

    init(currentTargetTitle: String?) {
        titleText = "Target: \(currentTargetTitle ?? "Select")"
        accessorySymbolName = "chevron.down"
        fixedWidth = 260
    }
}
