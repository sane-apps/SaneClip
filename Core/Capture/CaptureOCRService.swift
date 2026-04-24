import AppKit
import Foundation
import Vision

actor CaptureOCRService {
    struct RecognizedLine: Sendable {
        let text: String
        let bounds: CGRect
    }

    func recognizeText(in image: NSImage, language: CaptureOCRLanguage = .automatic) async throws -> String {
        guard let cgImage = image.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else {
            throw ScreenCaptureError.invalidImage
        }

        return try await recognizeText(in: cgImage, language: language)
    }

    func recognizeText(in cgImage: CGImage, language: CaptureOCRLanguage = .automatic) async throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if #available(macOS 13.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
        }

        if let languageCode = language.recognitionLanguageCode {
            request.recognitionLanguages = [languageCode]
            if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = false
            }
        } else if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        } else {
            request.recognitionLanguages = ["en-US"]
        }

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        let lines = (request.results ?? [])
            .compactMap { observation -> RecognizedLine? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return RecognizedLine(text: text, bounds: observation.boundingBox)
            }
            .sorted { lhs, rhs in
                let yDelta = abs(lhs.bounds.maxY - rhs.bounds.maxY)
                if yDelta > 0.03 {
                    return lhs.bounds.maxY > rhs.bounds.maxY
                }
                return lhs.bounds.minX < rhs.bounds.minX
            }

        return lines.map(\.text).joined(separator: "\n")
    }
}
