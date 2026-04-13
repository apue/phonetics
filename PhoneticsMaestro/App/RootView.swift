import SwiftUI

struct RootView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView(columnVisibility: $viewModel.splitViewVisibility) {
            List(AppScreen.allCases, selection: $viewModel.selectedScreen) { screen in
                Label(screen.title, systemImage: screen.systemImage)
                    .tag(screen)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(viewModel.isSidebarCollapsed ? "Show Sidebar" : "Hide Sidebar") {
                    viewModel.toggleSidebar()
                }
                .keyboardShortcut("\\", modifiers: [.command])
            }
        }
        .overlay {
            if viewModel.isInitializing {
                ProgressView("Initializing library…")
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert(
            "Initialization Failed",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch viewModel.selectedScreen {
        case .welcome:
            WelcomeView(
                isInitialized: viewModel.isInitialized,
                beginAction: {
                    viewModel.showTraining()
                },
                historyAction: {
                    viewModel.selectedScreen = .history
                },
                settingsAction: {
                    viewModel.selectedScreen = .settings
                }
            )
        case .training:
            TrainingCardView(viewModel: viewModel.trainingCardViewModel)
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }
}
