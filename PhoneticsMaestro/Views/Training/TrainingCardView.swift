import SwiftUI

struct TrainingCardView: View {
    @Bindable var viewModel: TrainingCardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Training Card")
                .font(.title)
                .fontWeight(.semibold)

            if let pair = viewModel.currentPair {
                HStack(spacing: 24) {
                    targetCard(label: "A", title: pair.leftText, ipa: pair.leftIPA)
                    targetCard(label: "B", title: pair.rightText, ipa: pair.rightIPA)
                }

                Text("Contrast \(pair.phonemeContrast) • Tier \(pair.tier.rawValue)")
                    .foregroundStyle(.secondary)

                perceptionSection(pair: pair)
            } else {
                ContentUnavailableView(
                    "No Pair Loaded",
                    systemImage: "waveform.badge.magnifyingglass",
                    description: Text("Initialize the local database to load the first minimal pair.")
                )
            }

            HStack(spacing: 12) {
                Button("Next Card") {
                    Task {
                        await viewModel.loadNextPair()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Reload") {
                    Task {
                        await viewModel.loadInitialPair()
                    }
                }
                .buttonStyle(.bordered)
            }

            Text("Recording, single-track playback, and ABAB comparison are available in the service layer and will be wired into the practice module next.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
        .alert(
            "Training Error",
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

    private func targetCard(label: String, title: String, ipa: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline.monospaced())
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 34, weight: .semibold))

            Text(ipa)
                .font(.title3.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 260, alignment: .leading)
        .padding(24)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func perceptionSection(pair: PhonePair) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Perception")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                Button("Random Test") {
                    Task {
                        do {
                            try await viewModel.playRandomTest()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Button(pair.leftText) {
                    Task {
                        await viewModel.submitPerceptionGuess(.left)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.perceptionState != .awaitingAnswer)

                Button(pair.rightText) {
                    Task {
                        await viewModel.submitPerceptionGuess(.right)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.perceptionState != .awaitingAnswer)
            }

            Text(feedbackText)
                .foregroundStyle(feedbackColor)

            HStack(spacing: 20) {
                statValue("LISTENS", value: "\(viewModel.sessionStats.listens)")
                statValue("CORRECT", value: "\(viewModel.sessionStats.correct)")
            }
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var feedbackText: String {
        switch viewModel.perceptionState {
        case .idle:
            return "Run a blind random test, then choose A or B."
        case .awaitingAnswer:
            return "Listening complete. Choose the target you heard."
        case let .correct(expected):
            return "Correct. The target was \(expected.rawValue.uppercased())."
        case let .incorrect(expected):
            return "Incorrect. Replaying the correct target: \(expected.rawValue.uppercased())."
        }
    }

    private var feedbackColor: Color {
        switch viewModel.perceptionState {
        case .correct:
            return .green
        case .incorrect:
            return .red
        case .idle, .awaitingAnswer:
            return .secondary
        }
    }

    private func statValue(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.monospacedDigit())
                .fontWeight(.semibold)
        }
    }
}
