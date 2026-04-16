import SwiftUI

struct TrainingCardView: View {
    @Bindable var viewModel: TrainingCardViewModel
    @State private var isRecordButtonPulsing = false
    @State private var isFeedbackHighlighted = false
    @State private var isTargetSelectorPresented = false
    @State private var feedbackResetTask: Task<Void, Never>?

    private let targetSelectorWidth: CGFloat = 340
    private let targetSelectorListHeight: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection

            if let card = viewModel.currentCard {
                contentBody(card: card)
                footerSection
            } else {
                ContentUnavailableView(
                    "No Training Card Loaded",
                    systemImage: "waveform.badge.magnifyingglass",
                    description: Text("Initialize the local database to load a training target.")
                )
            }
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

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TRAINING CARD")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(headerTitle)
                    .font(.system(size: 34, weight: .bold))

                Text(headerDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)

                if let currentTarget = viewModel.currentTarget {
                    Text("\(currentTarget.title) • \(currentTarget.group.sectionTitle)")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 12) {
                targetSelectorMenu
                taggingSection
            }
        }
    }

    @ViewBuilder
    private func contentBody(card: TrainingCardItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 24) {
                targetCard(
                    roleLabel: viewModel.selectedPracticeTarget == .left ? "SELECTED TARGET" : "LEFT TARGET",
                    title: card.leftText,
                    ipa: card.leftIPA,
                    option: .left
                )
                targetCard(
                    roleLabel: viewModel.selectedPracticeTarget == .right ? "SELECTED TARGET" : "RIGHT TARGET",
                    title: card.rightText,
                    ipa: card.rightIPA,
                    option: .right
                )
            }

            HStack(alignment: .top, spacing: 20) {
                perceptionSection(card: card)
                practiceSection(card: card)
            }
        }
    }

    private var footerSection: some View {
        HStack(spacing: 20) {
            statStrip
            Spacer(minLength: 0)
            navigationControls
        }
    }

    private var targetSelectorMenu: some View {
        Button("Target: \(viewModel.currentTarget?.title ?? "Select")") {
            isTargetSelectorPresented = true
        }
        .buttonStyle(.borderedProminent)
        .popover(isPresented: $isTargetSelectorPresented, arrowEdge: .bottom) {
            targetSelectorPopover
        }
    }

    private var targetSelectorPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Switch What You're Training")
                    .font(.headline)

                Text("Choose a target below. The list scrolls when there are more targets than fit.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(TrainingTargetSelectorSection.sections(from: viewModel.targets)) { section in
                        targetSelectorSection(section)
                    }
                }
                .padding(14)
            }
            .scrollIndicators(.visible)
            .frame(maxHeight: targetSelectorListHeight)
        }
        .frame(width: targetSelectorWidth)
        .padding(.bottom, 8)
    }

    private func targetSelectorSection(_ section: TrainingTargetSelectorSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.group.sectionTitle.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 6) {
                ForEach(section.targets) { target in
                    targetSelectorRow(target)
                }
            }
        }
    }

    private var taggingSection: some View {
        HStack(spacing: 12) {
            Button("★ Save") {
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

            Button("! Hard") {
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

    private func targetCard(
        roleLabel: String,
        title: String,
        ipa: String?,
        option: PairOption
    ) -> some View {
        Button {
            Task {
                await viewModel.tapTargetCard(option)
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(roleLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(viewModel.selectedPracticeTarget == option ? .blue : .secondary)
                    Spacer()
                    if viewModel.selectedPracticeTarget == option {
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Circle().fill(Color.accentColor))
                    }
                }

                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)

                if let ipa, !ipa.isEmpty {
                    Text("\(ipa) • \(option.rawValue.uppercased())")
                        .font(.title3.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Text(option.rawValue.uppercased())
                        .font(.title3.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
            .padding(24)
            .background(targetBackground(for: option), in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRecording)
    }

    @ViewBuilder
    private func perceptionSection(card: TrainingCardItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Perception")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Run a blind test, then decide whether you heard A or B.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("▶ Random Test") {
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
                .disabled(viewModel.isRecording)

                Button(card.leftText) {
                    Task {
                        await viewModel.submitPerceptionGuess(.left)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.perceptionState != .awaitingAnswer)

                Button(card.rightText) {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    @ViewBuilder
    private func practiceSection(card: TrainingCardItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Practice")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Selected target: \(selectedTargetLabel(for: card))")
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("Speed")
                    .foregroundStyle(.secondary)

                speedChip("0.75x", rate: 0.75)
                speedChip("1.0x", rate: 1.0)
                speedChip("1.25x", rate: 1.25)
            }

            VStack(alignment: .leading, spacing: 8) {
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
                    .tint(viewModel.isRecording ? .red : .primary)
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

                    Button("Stop") {
                        Task {
                            await viewModel.stopPlayback()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isPlaybackActive)
                    .keyboardShortcut(.escape, modifiers: [])
                }

                Text(Self.practiceHintText(
                    isRecording: viewModel.isRecording,
                    isABABLooping: viewModel.isABABLooping,
                    isPlaybackActive: viewModel.isPlaybackActive,
                    practices: viewModel.sessionStats.practices
                ))
                .font(.footnote)
                .foregroundStyle(viewModel.isRecording ? .red : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var statStrip: some View {
        HStack(spacing: 28) {
            statValue("LISTENS", value: "\(viewModel.sessionStats.listens)")
            statValue("CORRECT", value: correctStatText)
            statValue("PRACTICES", value: "\(viewModel.sessionStats.practices)")
            statValue("TIME", value: elapsedTimeText)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private func speedChip(_ title: String, rate: Float) -> some View {
        Button(title) {
            viewModel.playbackRate = rate
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(viewModel.playbackRate == rate ? Color.accentColor : Color.secondary.opacity(0.12))
        )
        .foregroundStyle(viewModel.playbackRate == rate ? .white : .primary)
    }

    private func targetSelectorRow(_ target: TrainingTargetSummary) -> some View {
        let isCurrent = target.id == viewModel.selectedTargetID

        return Button {
            isTargetSelectorPresented = false
            Task {
                await viewModel.selectTarget(id: target.id)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.title)
                        .font(.callout.weight(.semibold))
                    Text(target.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isCurrent ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    private var navigationControls: some View {
        HStack(spacing: 12) {
            Button("← Prev") {
                Task {
                    await viewModel.loadPreviousPair()
                }
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button("Reload") {
                Task {
                    await viewModel.reloadCurrentTarget()
                }
            }
            .buttonStyle(.bordered)

            Button("Next") {
                Task {
                    await viewModel.loadNextPair()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
    }

    private var headerTitle: String {
        viewModel.currentCard?.title ?? "Training"
    }

    private var headerDescription: String {
        guard let currentTarget else {
            return "Switch what you're training without leaving the main practice workspace."
        }

        switch currentTarget.currentItemType {
        case "sentence":
            return "Train connected speech and prosody by listening first, then comparing your own recording."
        default:
            return "Train the contrast between the selected A/B targets by listening first, then comparing your own recording."
        }
    }

    private var currentTarget: TrainingTargetSummary? {
        viewModel.currentTarget
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

    private func selectedTargetLabel(for card: TrainingCardItem) -> String {
        switch viewModel.selectedPracticeTarget {
        case .left:
            return "A • \(card.leftText)"
        case .right:
            return "B • \(card.rightText)"
        }
    }

    private var correctStatText: String {
        Self.correctCountText(correct: viewModel.sessionStats.correct)
    }

    static func correctCountText(correct: Int) -> String {
        "\(correct)"
    }

    static func practiceHintText(
        isRecording: Bool,
        isABABLooping: Bool,
        isPlaybackActive: Bool,
        practices: Int
    ) -> String {
        if isRecording {
            return "Recording in progress. Press Stop Record to save this attempt."
        }

        if isABABLooping {
            return "ABAB comparison is running for the selected target. Use Stop or A/B to end it."
        }

        if isPlaybackActive {
            return "Playback is active. Use Stop or start another playback action to interrupt it."
        }

        if practices == 0 {
            return "Record your first attempt to unlock Me and A/B playback."
        }

        return "Use Standard, Me, and A/B to compare your latest recording with the selected target."
    }

    private var elapsedTimeText: String {
        let minutes = viewModel.sessionStats.elapsedSeconds / 60
        let seconds = viewModel.sessionStats.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func targetBackground(for option: PairOption) -> some ShapeStyle {
        if viewModel.activePlaybackControl == .targetCard(option) {
            return Color.green.opacity(0.18)
        }

        if viewModel.selectedPracticeTarget == option {
            return Color.blue.opacity(0.16)
        }

        return Color.secondary.opacity(0.1)
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
