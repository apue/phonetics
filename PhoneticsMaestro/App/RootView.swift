import SwiftUI

public struct RootView: View {
    @Bindable var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $viewModel.splitViewVisibility) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Phonetics Maestro")
                        .font(.headline)
                        .padding(.bottom, 8)

                    ForEach(AppScreen.allCases) { screen in
                        sidebarButton(for: screen)
                    }

                    if viewModel.selectedScreen == .training {
                        sidebarSummaryCard(
                            title: "CURRENT TARGET",
                            primary: viewModel.trainingCardViewModel.currentTarget?.title ?? "Select",
                            secondary: viewModel.trainingCardViewModel.currentTarget?.subtitle ?? "No target selected",
                            tertiary: viewModel.trainingCardViewModel.currentTarget?.group.sectionTitle ?? "Training"
                        )

                        sidebarSummaryCard(
                            title: "SESSION",
                            primary: "\(viewModel.trainingCardViewModel.sessionStats.listens) / \(viewModel.trainingCardViewModel.sessionStats.correct)",
                            secondary: "Listens / Correct",
                            tertiary: elapsedTimeText
                        )
                    }

                    Spacer(minLength: 0)
                }
                .padding(24)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
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

    private func sidebarButton(for screen: AppScreen) -> some View {
        Button {
            viewModel.selectedScreen = screen
        } label: {
            Label(screen.title, systemImage: screen.systemImage)
                .font(.body.weight(viewModel.selectedScreen == screen ? .semibold : .regular))
                .foregroundStyle(viewModel.selectedScreen == screen ? Color.accentColor : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(viewModel.selectedScreen == screen ? Color.accentColor.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func sidebarSummaryCard(title: String, primary: String, secondary: String, tertiary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(primary)
                .font(.title3.weight(.bold))
            Text(secondary)
                .foregroundStyle(.secondary)
            Text(tertiary)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var elapsedTimeText: String {
        let elapsed = viewModel.trainingCardViewModel.sessionStats.elapsedSeconds
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
