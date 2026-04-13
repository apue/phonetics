import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel = SettingsViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section("Voice") {
                Picker("TTS Voice", selection: $viewModel.preferredVoiceName) {
                    ForEach(viewModel.availableVoiceNames, id: \.self) { voiceName in
                        Text(voiceName).tag(voiceName)
                    }
                }
            }

            Section("Microphone") {
                Picker("Input Device", selection: $viewModel.preferredMicrophoneName) {
                    ForEach(viewModel.availableMicrophoneNames, id: \.self) { microphoneName in
                        Text(microphoneName).tag(microphoneName)
                    }
                }
            }

            Section("ABAB Loop") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Interval \(viewModel.ababIntervalMilliseconds) ms")
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.ababIntervalMilliseconds) },
                            set: { viewModel.ababIntervalMilliseconds = Int($0.rounded()) }
                        ),
                        in: 150 ... 600,
                        step: 50
                    )
                }
            }

            Section {
                Button(viewModel.isSaving ? "Saving…" : "Save Settings") {
                    Task {
                        await viewModel.saveSettings()
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isSaving)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task {
            await viewModel.loadSettings()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading settings…")
            }
        }
        .alert(
            "Settings Error",
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
}
