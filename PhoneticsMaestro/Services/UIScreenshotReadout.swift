import AppKit
import Vision

struct UIScreenshotReadout: Sendable, Equatable {
    let onboardingText: String
    let trainingText: String
}

@MainActor
struct UIScreenshotReadoutBuilder {
    let outputDirectory: URL

    func build() throws -> UIScreenshotReadout {
        let rendered = try UIScreenshotRenderer(outputDirectory: outputDirectory).render()
        return UIScreenshotReadout(
            onboardingText: try recognizeText(at: rendered.onboarding),
            trainingText: try recognizeText(at: rendered.training)
        )
    }

    private func recognizeText(at url: URL) throws -> String {
        guard
            let image = NSImage(contentsOf: url),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            throw UIScreenshotReadoutError.unreadableImage(url.path)
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        let observations = (request.results ?? [])
            .sorted { lhs, rhs in
                if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.02 {
                    return lhs.boundingBox.midY > rhs.boundingBox.midY
                }

                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }

        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        return lines
            .joined(separator: " | ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

private enum UIScreenshotReadoutError: Error {
    case unreadableImage(String)
}
