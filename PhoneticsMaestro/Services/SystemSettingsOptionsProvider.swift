import AVFoundation

struct SystemSettingsOptionsProvider: SettingsOptionsProviding {
    func availableVoiceNames() -> [String] {
        let names = AVSpeechSynthesisVoice.speechVoices().map(\.name)
        return uniqueOptions(from: names)
    }

    func availableMicrophoneNames() -> [String] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        let names = discoverySession.devices.map(\.localizedName)
        return uniqueOptions(from: names)
    }

    private func uniqueOptions(from names: [String]) -> [String] {
        let ordered = ["System Default"] + names.sorted()
        return ordered.reduce(into: [String]()) { result, name in
            if !result.contains(name) {
                result.append(name)
            }
        }
    }
}
