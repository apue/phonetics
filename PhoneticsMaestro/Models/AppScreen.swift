enum AppScreen: String, CaseIterable, Identifiable {
    case welcome
    case training
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .welcome:
            return "Begin"
        case .training:
            return "Training"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .welcome:
            return "play.circle"
        case .training:
            return "waveform"
        case .history:
            return "clock.arrow.circlepath"
        case .settings:
            return "gearshape"
        }
    }
}
