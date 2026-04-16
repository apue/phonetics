enum TrainingTargetGroup: String, CaseIterable, Sendable, Identifiable {
    case soundContrasts
    case linkingReduction
    case stressIntonation

    var id: String { rawValue }

    var sectionTitle: String {
        switch self {
        case .soundContrasts:
            "Sound Contrasts"
        case .linkingReduction:
            "Linking / Reduction"
        case .stressIntonation:
            "Stress / Intonation"
        }
    }
}
