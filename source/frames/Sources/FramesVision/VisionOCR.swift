//
//  VisionOCR.swift
//  FramesVision
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import Foundation
import Frames
import Vision

// The `vision` OCR provider: Vision's accurate text recognition on the frame the decoder reads, in Korean and English.
// Every setting that changes what is recognised is fixed, so the same picture gives the same lines. Vision's accurate
// line box reaches below the text by up to a third of the text's height, so each is cut to the ink inside it.
package struct VisionOCR: Sendable {
    // MARK: - Property
    private static let languages = ["ko-KR", "en-US"]

    private let decoder: any MediaDecoder
    private let converter = ImageConverter()
    private let scanner = InkScanner()

    // MARK: - Initializer
    package init(decoder: any MediaDecoder) {
        self.decoder = decoder
    }

    // MARK: - Public
    // MARK: - Private
    private func line(
        from observation: VNRecognizedTextObservation,
        in picture: Bitmap
    ) -> RecognisedLine? {
        guard let text = observation.topCandidates(1).first?.string else { return nil }
        let size = Size(width: Double(picture.width), height: Double(picture.height))
        let box = Rectangle(normalizedRect: observation.boundingBox, in: size)

        return RecognisedLine(text: text, rectangle: scanner.fitted(box, in: picture))
    }
}

extension VisionOCR: OCRProvider {
    // MARK: - Lifecycle
    package func lines(
        in file: MediaFile,
        atMediaTime time: Double
    ) throws -> [RecognisedLine] {
        let index = file.frameIndex(at: time)
        let picture = try decoder.picture(of: file, atFrame: index)
        let image = try converter.image(of: picture, file: file.path, index: index)

        let request = VNRecognizeTextRequest()
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLevel = .accurate
        request.recognitionLanguages = Self.languages
        request.automaticallyDetectsLanguage = false
        request.usesLanguageCorrection = true
        request.customWords = []
        request.minimumTextHeight = 0
        try VNImageRequestHandler(cgImage: image).perform([request])

        return (request.results ?? []).compactMap { line(from: $0, in: picture) }
    }
}
