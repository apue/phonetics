struct AppSettings: Codable, Equatable, Sendable {
    var preferredVoiceName: String
    var preferredMicrophoneName: String
    var ababIntervalMilliseconds: Int
    var hasDismissedOnboarding: Bool

    init(
        preferredVoiceName: String = "System Default",
        preferredMicrophoneName: String = "System Default",
        ababIntervalMilliseconds: Int = 300,
        hasDismissedOnboarding: Bool = false
    ) {
        self.preferredVoiceName = preferredVoiceName
        self.preferredMicrophoneName = preferredMicrophoneName
        self.ababIntervalMilliseconds = ababIntervalMilliseconds
        self.hasDismissedOnboarding = hasDismissedOnboarding
    }
}
