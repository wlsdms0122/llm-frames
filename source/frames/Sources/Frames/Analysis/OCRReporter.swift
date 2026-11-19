//
//  OCRReporter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Recognises the lines of an image or of video frames with the OCR provider in the recognition languages, nil where
// the provider detects them, and reports them as `ocr` prints them, in reading order, the order a text area's `nth`
// counts them in. Each frame is the one shown at its media time.
package struct OCRReporter: Sendable {
    // MARK: - Property
    private let mediaFacts: any MediaFactProvider
    private let ocr: any OCRProvider
    private let languages: [LanguageTag]?
    private let order = ReadingOrder()

    // MARK: - Initializer
    package init(
        mediaFacts: any MediaFactProvider,
        ocr: any OCRProvider,
        languages: [LanguageTag]?
    ) {
        self.mediaFacts = mediaFacts
        self.ocr = ocr
        self.languages = languages
    }

    // MARK: - Public
    package func report(
        of path: String,
        at selection: TimeSelection = .start
    ) throws -> OCRReport {
        guard let probed = try mediaFacts.probedMedia(of: path) else { throw AnalysisError.missingMedia(file: path) }
        guard let size = probed.size else { throw AnalysisError.noPicture(file: path) }

        let file = MediaFile(path: path, probed: probed)
        let frames = try times(selection, in: probed, file: path).map { time in
            OCRFrame(time: time, lines: order.sorted(try lines(in: file, atMediaTime: time, asked: selection)))
        }

        return OCRReport(size: size, languages: languages, frames: frames)
    }

    // MARK: - Private
    // A failure names the option that chose the frame, or the command when none did.
    private func lines(
        in file: MediaFile,
        atMediaTime time: Double,
        asked selection: TimeSelection
    ) throws -> [RecognisedLine] {
        let option = switch selection {
        case .start:
            "ocr"

        case .at:
            "--at"

        case .range:
            "--from"
        }

        return try Result { try ocr.lines(in: file, atMediaTime: time, languages: languages) }
            .mapError { error in
                ProviderError.failed(
                    provider: .ocr,
                    place: Place(components: [.key(option)]),
                    kind: nil,
                    picture: ProviderPicture(media: file.path, mediaTime: time),
                    message: "\(error)"
                )
            }
            .get()
    }

    private func times(
        _ selection: TimeSelection,
        in probed: ProbedMedia,
        file: String
    ) throws -> [Double] {
        if probed.kind == .image {
            guard selection == .start else { throw AnalysisError.timeOnImage(file: file) }

            return [0]
        }

        let end = probed.duration
        switch selection {
        case .start:
            return [0]

        case let .at(time):
            try checkTime("--at", time, end: end, file: file)
            return [time]

        case let .range(range):
            guard range.step.timeTicks > 0 else { throw AnalysisError.nonPositiveStep(step: range.step) }

            let start = range.start
            let stop = range.last(end: end)
            try checkTime("--from", start, end: end, file: file)
            guard stop.roundedTime <= end.roundedTime else {
                throw AnalysisError.afterMediaEnd(option: "--to", time: stop, file: file, end: end)
            }
            guard start.roundedTime < stop.roundedTime else { throw AnalysisError.emptyRange(from: start, to: stop) }

            return range.times(before: stop)
        }
    }

    // A time a frame is read at lies in the media, [0, end).
    private func checkTime(
        _ option: String,
        _ time: Double,
        end: Double,
        file: String
    ) throws {
        guard time.roundedTime >= 0 else {
            throw AnalysisError.beforeMediaStart(option: option, time: time, file: file)
        }
        guard time.roundedTime < end.roundedTime else {
            throw AnalysisError.atOrAfterMediaEnd(option: option, time: time, file: file, end: end)
        }
    }
}
