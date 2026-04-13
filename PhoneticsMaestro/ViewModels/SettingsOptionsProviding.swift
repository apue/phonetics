protocol SettingsOptionsProviding: Sendable {
    func availableVoiceNames() -> [String]
    func availableMicrophoneNames() -> [String]
}
