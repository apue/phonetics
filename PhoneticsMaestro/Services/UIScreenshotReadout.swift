import AppKit
import Vision

struct UIScreenshotReadout: Sendable, Equatable {
    let onboardingText: String
    let onboardingMarkers: [String]
    let onboardingSections: [String]
    let trainingText: String
    let trainingMarkers: [String]
    let trainingSections: [String]
}

enum UIScreenshotReadoutKind: Sendable {
    case onboarding
    case training
}

struct UIScreenshotReadoutAnalysis: Sendable, Equatable {
    let rawText: String
    let markers: [String]
    let sections: [String]
}

enum UIScreenshotReadoutAnalyzer {
    static func analyze(text: String, kind: UIScreenshotReadoutKind) -> UIScreenshotReadoutAnalysis {
        let normalizedText = normalize(text)
        let markerDefinitions = markerCatalog(for: kind)
        let markers = markerDefinitions.compactMap { definition in
            matches(definition.keywords, in: normalizedText) ? definition.name : nil
        }
        let sections = sectionCatalog(for: kind).compactMap { definition in
            matches(definition.keywords, in: normalizedText) ? definition.name : nil
        }

        return UIScreenshotReadoutAnalysis(
            rawText: text,
            markers: markers,
            sections: sections
        )
    }

    private static func markerCatalog(for kind: UIScreenshotReadoutKind) -> [UIScreenshotMatchDefinition] {
        switch kind {
        case .onboarding:
            return [
                .init(name: "first_run", keywords: ["first run"]),
                .init(name: "welcome", keywords: ["welcome"]),
                .init(name: "intro", keywords: ["one time introduction"]),
                .init(name: "begin_training", keywords: ["begin training"]),
                .init(name: "not_now", keywords: ["not now"])
            ]
        case .training:
            return [
                .init(name: "begin", keywords: ["begin"]),
                .init(name: "current_target", keywords: ["current target"]),
                .init(name: "session", keywords: ["session"]),
                .init(name: "target", keywords: ["target"]),
                .init(name: "perception", keywords: ["perception"]),
                .init(name: "practice", keywords: ["practice"]),
                .init(name: "listens", keywords: ["listens"]),
                .init(name: "correct", keywords: ["correct"]),
                .init(name: "practices", keywords: ["practices"]),
                .init(name: "time", keywords: ["time"])
            ]
        }
    }

    private static func sectionCatalog(for kind: UIScreenshotReadoutKind) -> [UIScreenshotMatchDefinition] {
        switch kind {
        case .onboarding:
            return [
                .init(name: "overlay", keywords: ["first run"]),
                .init(name: "actions", keywords: ["begin training", "not now"])
            ]
        case .training:
            return [
                .init(name: "sidebar", keywords: ["current target", "session"]),
                .init(name: "header", keywords: ["target"]),
                .init(name: "interaction", keywords: ["perception", "practice"]),
                .init(name: "stats", keywords: ["listens", "correct", "practices", "time"])
            ]
        }
    }

    private static func normalize(_ text: String) -> String {
        let scalarView = text.lowercased().unicodeScalars.map { scalar -> UnicodeScalar in
            CharacterSet.alphanumerics.contains(scalar) ? scalar : UnicodeScalar(32)
        }
        return String(String.UnicodeScalarView(scalarView))
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func matches(_ keywords: [String], in normalizedText: String) -> Bool {
        keywords.allSatisfy { normalizedText.contains(normalize($0)) }
    }
}

private struct UIScreenshotMatchDefinition {
    let name: String
    let keywords: [String]
}

@MainActor
struct UIScreenshotReadoutBuilder {
    let outputDirectory: URL

    func build() throws -> UIScreenshotReadout {
        let rendered = try UIScreenshotRenderer(outputDirectory: outputDirectory).render()
        let onboarding = try recognizeReadout(at: rendered.onboarding, kind: .onboarding)
        let training = try recognizeReadout(at: rendered.training, kind: .training)
        return UIScreenshotReadout(
            onboardingText: onboarding.rawText,
            onboardingMarkers: onboarding.markers,
            onboardingSections: onboarding.sections,
            trainingText: training.rawText,
            trainingMarkers: training.markers,
            trainingSections: training.sections
        )
    }

    private func recognizeReadout(at url: URL, kind: UIScreenshotReadoutKind) throws -> UIScreenshotReadoutAnalysis {
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
        let rawText = lines
            .joined(separator: " | ")
            .replacingOccurrences(of: "\n", with: " ")

        return UIScreenshotReadoutAnalyzer.analyze(text: rawText, kind: kind)
    }
}

private enum UIScreenshotReadoutError: Error {
    case unreadableImage(String)
}
