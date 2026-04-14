import PhoneticsCore
import SwiftUI

@main
struct PhoneticsMaestroApp: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .task {
                    await viewModel.initialize()
                }
        }
        .defaultSize(width: 980, height: 640)
    }
}
