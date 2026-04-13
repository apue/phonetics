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
                    targetCard(title: pair.leftText, ipa: pair.leftIPA)
                    targetCard(title: pair.rightText, ipa: pair.rightIPA)
                }

                Text("Contrast \(pair.phonemeContrast) • Tier \(pair.tier.rawValue)")
                    .foregroundStyle(.secondary)
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

            Text("Audio playback, recording, and ABAB comparison are intentionally deferred to Phase 2.")
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

    private func targetCard(title: String, ipa: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
}
