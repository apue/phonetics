protocol AppInitializing: Sendable {
    func initialize() async throws
}

extension DataService: AppInitializing {}
