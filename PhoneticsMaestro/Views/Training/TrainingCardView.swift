import SwiftUI

struct TrainingCardView: View {
    @Bindable var viewModel: TrainingCardViewModel
    @State private var isRecordButtonPulsing = false
    @State private var isFeedbackHighlighted = false
    @State private var feedbackResetTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Training Card")
                .font(.title)
                .fontWeight(.semibold)

            if let pair = viewModel.currentPair {
                HStack(spacing: 24) {
                    targetCard(label: "A", title: pair.leftText, ipa: pair.leftIPA, option: .left)
                    targetCard(label: "B", title: pair.rightText, ipa: pair.rightIPA, option: .right)
                }

                Text("Contrast \(pair.phonemeContrast) • Tier \(pair.tier.rawValue)")
                    .foregroundStyle(.secondary)

                taggingSection
                perceptionSection(pair: pair)
                practiceSection(pair: pair)
            } else {
                ContentUnavailableView(
                    "No Pair Loaded",
                    systemImage: "waveform.badge.magnifyingglass",
                    description: Text("Initialize the local database to load the first minimal pair.")
                )
            }

            HStack(spacing: 12) {
                Button("Previous Card") {
                    Task {
                        await viewModel.loadPreviousPair()
                    }
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("Next Card") {
                    Task {
                        await viewModel.loadNextPair()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.rightArrow, modifiers: [])

                Button("Reload") {
                    Task {
                        await viewModel.loadInitialPair()
                    }
                }
                .buttonStyle(.bordered)
            }

            Text("The current practice target is highlighted above. Use Record to capture yourself, then compare against the selected standard target.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            syncRecordingAnimation()
            triggerFeedbackHighlight(for: viewModel.feedbackHighlight)
        }
        .onChange(of: viewModel.isRecording) { _, _ in
            syncRecordingAnimation()
        }
        .onChange(of: viewModel.feedbackHighlight) { _, newValue in
            triggerFeedbackHighlight(for: newValue)
        }
        .onDisappear {
            feedbackResetTask?.cancel()
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

    private var taggingSection: some View {
        HStack(spacing: 12) {
            Button(viewModel.isSaved ? "★ Saved" : "☆ Save") {
                Task {
                    do {
                        try await viewModel.toggleSaved()
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.bordered)
            .tint(viewModel.isSaved ? .yellow : .secondary)

            Button(viewModel.isHard ? "! Hard" : "Mark Hard") {
                Task {
                    do {
                        try await viewModel.toggleHard()
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.bordered)
            .tint(viewModel.isHard ? .orange : .secondary)
        }
    }

    private func targetCard(label: String, title: String, ipa: String, option: PairOption) -> some View {
        Button {
            viewModel.selectPracticeTarget(option)
        } label: {
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
            .background(targetBackground(for: option), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
                .keyboardShortcut(.space, modifiers: [])

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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(feedbackBackground, in: RoundedRectangle(cornerRadius: 12))
                .scaleEffect(isFeedbackHighlighted ? 1.02 : 1.0)
                .animation(.easeOut(duration: 0.25), value: isFeedbackHighlighted)

            HStack(spacing: 20) {
                statValue("LISTENS", value: "\(viewModel.sessionStats.listens)")
                statValue("CORRECT", value: correctStatText)
            }
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func practiceSection(pair: PhonePair) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Practice")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Selected target: \(selectedTargetLabel(for: pair))")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(viewModel.isRecording ? "Stop Record" : "Record") {
                    Task {
                        do {
                            try await viewModel.toggleRecording()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isRecording ? .red : .accentColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(viewModel.isRecording ? 0.45 : 0.0), lineWidth: 2)
                        .scaleEffect(isRecordButtonPulsing ? 1.08 : 0.96)
                        .opacity(isRecordButtonPulsing ? 0.2 : 0.0)
                        .animation(
                            viewModel.isRecording
                                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                : .easeOut(duration: 0.2),
                            value: isRecordButtonPulsing
                        )
                }
                .scaleEffect(isRecordButtonPulsing ? 1.03 : 1.0)
                .shadow(color: Color.red.opacity(isRecordButtonPulsing ? 0.2 : 0.0), radius: 14)
                .animation(
                    viewModel.isRecording
                        ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                        : .easeOut(duration: 0.2),
                    value: isRecordButtonPulsing
                )
                .keyboardShortcut("r", modifiers: [])

                Button("Standard") {
                    Task {
                        do {
                            try await viewModel.playSelectedStandard()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRecording)

                Button("Me") {
                    Task {
                        do {
                            try await viewModel.playUserRecording()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRecording || viewModel.sessionStats.practices == 0)

                Button(viewModel.isABABLooping ? "Stop A/B" : "A/B") {
                    Task {
                        do {
                            try await viewModel.toggleABABLoop()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRecording || viewModel.sessionStats.practices == 0)
            }

            Text(practiceFeedbackText)
                .foregroundStyle(viewModel.isRecording ? .red : .secondary)

            HStack(spacing: 20) {
                statValue("PRACTICES", value: "\(viewModel.sessionStats.practices)")
                statValue("TIME", value: elapsedTimeText)
                statValue("TARGET", value: viewModel.selectedPracticeTarget.rawValue.uppercased())
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

    private var feedbackBackground: Color {
        switch viewModel.feedbackHighlight {
        case .success:
            return Color.green.opacity(isFeedbackHighlighted ? 0.18 : 0.08)
        case .error:
            return Color.red.opacity(isFeedbackHighlighted ? 0.18 : 0.08)
        case nil:
            return Color.secondary.opacity(0.08)
        }
    }

    private var practiceFeedbackText: String {
        if viewModel.isRecording {
            return "Recording in progress. Press Stop Record to save this attempt."
        }

        if viewModel.isABABLooping {
            return "ABAB comparison is running for the selected target."
        }

        if viewModel.sessionStats.practices == 0 {
            return "Record your first attempt to unlock Me and A/B playback."
        }

        return "Use Standard, Me, and A/B to compare your latest recording with the selected target."
    }

    private func selectedTargetLabel(for pair: PhonePair) -> String {
        switch viewModel.selectedPracticeTarget {
        case .left:
            return "A • \(pair.leftText)"
        case .right:
            return "B • \(pair.rightText)"
        }
    }

    private var correctStatText: String {
        "\(viewModel.sessionStats.correct)/\(viewModel.sessionStats.listens)"
    }

    private var elapsedTimeText: String {
        let minutes = viewModel.sessionStats.elapsedSeconds / 60
        let seconds = viewModel.sessionStats.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func targetBackground(for option: PairOption) -> some ShapeStyle {
        if viewModel.selectedPracticeTarget == option {
            return Color.accentColor.opacity(0.2)
        }

        return Color.secondary.opacity(0.12)
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

    private func syncRecordingAnimation() {
        isRecordButtonPulsing = viewModel.isRecording
    }

    private func triggerFeedbackHighlight(for highlight: TrainingFeedbackHighlight?) {
        feedbackResetTask?.cancel()
        guard highlight != nil else {
            isFeedbackHighlighted = false
            return
        }

        isFeedbackHighlighted = true
        feedbackResetTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                isFeedbackHighlighted = false
            }
        }
    }
}
