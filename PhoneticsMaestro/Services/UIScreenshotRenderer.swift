import AppKit
import SwiftUI

@MainActor
struct UIScreenshotRenderer {
    let outputDirectory: URL

    func render() throws -> (onboarding: URL, training: URL) {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let onboardingViewModel = makeTrainingFixture()
        let trainingViewModel = makeTrainingFixture()

        let onboardingURL = outputDirectory.appending(path: "onboarding.png", directoryHint: .notDirectory)
        let trainingURL = outputDirectory.appending(path: "training.png", directoryHint: .notDirectory)

        try render(
            ScreenshotShellView(
                detail: TrainingCardView(viewModel: onboardingViewModel),
                overlayContent: AnyView(
                    OnboardingView(
                        beginAction: {},
                        dismissAction: {}
                    )
                )
            ),
            to: onboardingURL,
            size: CGSize(width: 1440, height: 960)
        )
        try render(
            ScreenshotShellView(
                detail: TrainingCardView(viewModel: trainingViewModel),
                overlayContent: nil
            ),
            to: trainingURL,
            size: CGSize(width: 1440, height: 960)
        )

        return (onboardingURL, trainingURL)
    }

    private func makeTrainingFixture() -> TrainingCardViewModel {
        let trainingViewModel = TrainingCardViewModel(
            dataService: ScreenshotTrainingDataService(),
            audioService: ScreenshotTrainingAudioService(),
            sessionDateProvider: { "2026-04-16" }
        )

        let pair = PhonePair(
            id: 1,
            phonemeContrast: "ʌ-æ",
            tier: .phoneme,
            difficulty: 1,
            leftText: "but",
            leftIPA: "/bʌt/",
            rightText: "bat",
            rightIPA: "/bæt/"
        )

        trainingViewModel.currentPair = pair
        trainingViewModel.selectedPracticeTarget = .left
        trainingViewModel.sessionStats = SessionStats(listens: 12, correct: 9, practices: 4, elapsedSeconds: 154)
        trainingViewModel.perceptionState = .awaitingAnswer
        return trainingViewModel
    }

    private func render<V: View>(_ view: V, to url: URL, size: CGSize) throws {
        let content = view
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 2

        guard let image = renderer.nsImage else {
            throw UIScreenshotRendererError.renderFailed
        }

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw UIScreenshotRendererError.encodeFailed
        }

        try pngData.write(to: url)
    }
}

private enum UIScreenshotRendererError: Error {
    case renderFailed
    case encodeFailed
}

private actor ScreenshotTrainingDataService: TrainingDataServing {
    func fetchNextPair(afterID: Int64?) async throws -> PhonePair? { nil }
    func fetchPreviousPair(beforeID: Int64?) async throws -> PhonePair? { nil }
    func fetchPairTagState(for itemID: Int64) async throws -> TrainingTagState { .init(isSaved: false, isHard: false) }
    func fetchPairSessionStats(for itemID: Int64, sessionDate: String) async throws -> SessionStats { .init() }
    func updatePairTagState(for itemID: Int64, sessionDate: String, isSaved: Bool, isHard: Bool) async throws {}
    func updatePairSessionStats(
        for itemID: Int64,
        sessionDate: String,
        stats: SessionStats,
        isSaved: Bool,
        isHard: Bool
    ) async throws {}
}

private actor ScreenshotTrainingAudioService: TrainingAudioServing {
    func currentState() async -> AudioState { .idle }
    func playRandomTest(options: [String]) async throws -> Int { 0 }
    func playStandard(for text: String) async throws {}
    func startRecording(itemType: String, itemID: Int64, attempt: Int, sessionDate: String) async throws -> URL {
        FileManager.default.temporaryDirectory.appending(path: "recording.m4a", directoryHint: .notDirectory)
    }
    func stopRecording() async throws -> URL {
        FileManager.default.temporaryDirectory.appending(path: "recording.m4a", directoryHint: .notDirectory)
    }
    func playUserRecording() async throws {}
    func startABABLoop(standardText: String) async throws {}
    func stop() async {}
}

private struct ScreenshotShellView<Detail: View>: View {
    let detail: Detail
    let overlayContent: AnyView?

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Phonetics Maestro")
                        .font(.headline)
                        .padding(.bottom, 10)

                    shellSidebarItem("Training", selected: true)
                    shellSidebarItem("History", selected: false)
                    shellSidebarItem("Settings", selected: false)

                    Spacer()
                }
                .padding(24)
                .frame(width: 220)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .controlBackgroundColor))

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(nsColor: .windowBackgroundColor))
            }

            if let overlayContent {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()

                overlayContent
            }
        }
    }

    private func shellSidebarItem(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(.body.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? Color.accentColor : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
    }
}
