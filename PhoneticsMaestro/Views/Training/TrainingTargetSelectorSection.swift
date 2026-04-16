struct TrainingTargetSelectorSection: Equatable, Sendable, Identifiable {
    let group: TrainingTargetGroup
    let targets: [TrainingTargetSummary]

    var id: TrainingTargetGroup { group }

    static func sections(from targets: [TrainingTargetSummary]) -> [TrainingTargetSelectorSection] {
        TrainingTargetGroup.allCases.compactMap { group in
            let groupTargets = targets.filter { $0.group == group }
            guard !groupTargets.isEmpty else {
                return nil
            }

            return TrainingTargetSelectorSection(group: group, targets: groupTargets)
        }
    }
}
