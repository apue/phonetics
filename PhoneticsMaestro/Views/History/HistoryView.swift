import SwiftUI

struct HistoryView: View {
    @State private var viewModel: HistoryViewModel

    init(viewModel: HistoryViewModel = HistoryViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.sessions.isEmpty {
                ContentUnavailableView(
                    "History",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    description: Text("Complete a few training sessions to see summary history.")
                )
            } else {
                List(viewModel.sessions) { session in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.sessionDate)
                            .font(.headline)

                        HStack(spacing: 16) {
                            Text("Time \(formattedDuration(session.totalTimeSpentSec))")
                            Text("Accuracy \(session.totalCorrect)/\(session.totalListens)")
                            Text("Practices \(session.totalPractices)")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading history…")
            }
        }
        .task {
            await viewModel.loadHistory()
        }
        .alert(
            "History Error",
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

    private func formattedDuration(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
