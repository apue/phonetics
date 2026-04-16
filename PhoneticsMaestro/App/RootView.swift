import SwiftUI

public struct RootView: View {
    @Bindable var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $viewModel.splitViewVisibility) {
            List(AppScreen.allCases, selection: $viewModel.selectedScreen) { screen in
                Label(screen.title, systemImage: screen.systemImage)
                    .tag(screen)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            ZStack {
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if viewModel.shouldShowOnboarding {
                    Color.black.opacity(0.08)
                        .ignoresSafeArea()

                    OnboardingView(
                        beginAction: {
                            Task {
                                await viewModel.dismissOnboarding()
                            }
                        },
                        dismissAction: {
                            Task {
                                await viewModel.dismissOnboarding()
                            }
                        }
                    )
                    .padding(32)
                }
            }
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
        case .training:
            TrainingCardView(viewModel: viewModel.trainingCardViewModel)
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }
}
