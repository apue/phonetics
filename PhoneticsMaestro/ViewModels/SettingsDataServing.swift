protocol SettingsDataServing: Sendable {
    func fetchSettings() async throws -> AppSettings
    func updateSettings(_ settings: AppSettings) async throws
}
