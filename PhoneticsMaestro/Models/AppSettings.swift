struct AppSettings: Codable, Equatable, Sendable {
    var preferredVoiceName: String
    var preferredMicrophoneName: String
    var ababIntervalMilliseconds: Int

    init(
        preferredVoiceName: String = "System Default",
        preferredMicrophoneName: String = "System Default",
        ababIntervalMilliseconds: Int = 300
    ) {
        self.preferredVoiceName = preferredVoiceName
        self.preferredMicrophoneName = preferredMicrophoneName
        self.ababIntervalMilliseconds = ababIntervalMilliseconds
    }
}
