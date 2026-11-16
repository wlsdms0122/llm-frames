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
// Every setting that changes what is recognised is fixed, so the same picture gives the same lines.
package struct VisionOCR: Sendable {
    // MARK: - Property
    private static let languages = ["ko-KR", "en-US"]

    private let decoder: any MediaDecoder
    private let converter = ImageConverter()

    // MARK: - Initializer
    package init(decoder: any MediaDecoder) {
        self.decoder = decoder
    }

    // MARK: - Public
    // MARK: - Private
    // Vision's boxes are fractions of the picture from its bottom left, and lines are in media pixels from the top
    // left.
    private func line(
        from observation: VNRecognizedTextObservation,
        width: Double,
        height: Double
    ) -> RecognisedLine? {
        guard let text = observation.topCandidates(1).first?.string else { return nil }
        let box = observation.boundingBox

        return RecognisedLine(
            text: text,
            rectangle: Rectangle(
                x: box.minX * width,
                y: (1 - box.maxY) * height,
                width: box.width * width,
                height: box.height * height
            )
        )
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

        return (request.results ?? []).compactMap { observation in
            line(from: observation, width: Double(picture.width), height: Double(picture.height))
        }
    }
}
