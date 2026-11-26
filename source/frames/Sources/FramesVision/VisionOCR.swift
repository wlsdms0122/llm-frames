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

// The `vision` OCR provider: Vision's accurate text recognition on the analysis picture the decoder reads, in the
// recognition languages given, or in the language Vision detects without them. A page of a PDF is read whole at the
// provider scale, over white, and its lines are given in its points. Every other setting that changes what
// is recognised is fixed, so the same picture gives the same lines. Vision's accurate line box reaches below the text
// by up to a third of the text's height, so each is cut to the ink inside it.
package struct VisionOCR: Sendable {
    // MARK: - Property
    private let decoder: any MediaDecoder
    private let converter = ImageConverter()
    private let scanner = InkScanner()

    // MARK: - Initializer
    package init(decoder: any MediaDecoder) {
        self.decoder = decoder
    }

    // MARK: - Public
    // MARK: - Private
    // Vision's identifiers for the tags, matched ignoring case as BCP 47 compares tags. A tag Vision has no model for
    // stops before anything is read.
    private func recognitionLanguages(
        _ languages: [LanguageTag],
        for request: VNRecognizeTextRequest
    ) throws -> [String] {
        let supported = try request.supportedRecognitionLanguages()

        return try languages.map { language in
            guard let identifier = supported.first(where: { $0.lowercased() == language.text.lowercased() }) else {
                throw VisionError.unsupportedLanguage(tag: language.text, supported: supported)
            }

            return identifier
        }
    }

    // The line in the picture's pixels, divided by `scale`, the pixels per media pixel it was read at.
    private func line(
        from observation: VNRecognizedTextObservation,
        in picture: Bitmap,
        scale: Double
    ) -> RecognisedLine? {
        guard let text = observation.topCandidates(1).first?.string else { return nil }
        let size = Size(width: Double(picture.width), height: Double(picture.height))
        let box = scanner.fitted(Rectangle(normalizedRect: observation.boundingBox, in: size), in: picture)
        let rectangle = Rectangle(
            x: box.x / scale,
            y: box.y / scale,
            width: box.width / scale,
            height: box.height / scale
        )

        return RecognisedLine(text: text, rectangle: rectangle)
    }
}

extension VisionOCR: OCRProvider {
    // MARK: - Lifecycle
    package func lines(
        in file: MediaFile,
        atMediaTime time: Double,
        languages: [LanguageTag]?,
        colorSpace: ColorSpace?
    ) throws -> [RecognisedLine] {
        let request = VNRecognizeTextRequest()
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLevel = .accurate
        request.recognitionLanguages = try languages.map { try recognitionLanguages($0, for: request) } ?? []
        request.automaticallyDetectsLanguage = languages == nil
        request.usesLanguageCorrection = true
        request.customWords = []
        request.minimumTextHeight = 0

        let reading = PictureReading.analysis(colorSpace: colorSpace)
        let index = file.frameIndex(at: time)
        let (picture, scale) = if file.page != nil {
            try decoder.providerPicture(ofPage: file, reading: reading)
        } else {
            (try decoder.picture(of: file, atFrame: index, play: .file, reading: reading).bitmap, 1.0)
        }
        let image = try converter.image(of: picture, file: file.path, index: index)
        try VNImageRequestHandler(cgImage: image).perform([request])

        return (request.results ?? []).compactMap { line(from: $0, in: picture, scale: scale) }
    }
}
