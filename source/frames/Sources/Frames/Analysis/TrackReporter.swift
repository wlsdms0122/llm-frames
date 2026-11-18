//
//  TrackReporter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Finds an area in a video at media time `--at` and follows it with the tracker provider, as `track` on a clip does,
// and reports it as `track` prints it. The area is JSON text in one of a document's area forms, and is followed as
// found, before padding: a text form with OCR, a rectangle as written. It is followed over the whole video, or over
// the frames shown from `--at` to `--to`, either way.
package struct TrackReporter: Sendable {
    // MARK: - Property
    private static let place = Place(components: [.key("--area")])
    private static let kind = "area"

    private let mediaFacts: any MediaFactProvider
    private let tracker: any TrackerProvider
    private let finder: AreaFinder
    private let checker = KeyChecker()

    // MARK: - Initializer
    package init(
        mediaFacts: any MediaFactProvider,
        ocr: any OCRProvider,
        tracker: any TrackerProvider
    ) {
        self.mediaFacts = mediaFacts
        self.tracker = tracker
        self.finder = AreaFinder(ocr: ocr)
    }

    // MARK: - Public
    package func report(
        of path: String,
        area text: String,
        at time: Double,
        to end: Double? = nil
    ) throws -> TrackReport {
        let form = try area(text)
        guard let probed = try mediaFacts.probedMedia(of: path) else { throw AnalysisError.missingMedia(file: path) }
        guard probed.kind == .video, let size = probed.size else {
            throw AnalysisError.notVideo(file: path, kind: probed.kind)
        }

        let duration = probed.duration
        guard time.roundedTime >= 0 else {
            throw AnalysisError.beforeMediaStart(option: "--at", time: time, file: path)
        }
        guard time.roundedTime < duration.roundedTime else {
            throw AnalysisError.atOrAfterMediaEnd(option: "--at", time: time, file: path, end: duration)
        }
        if let end {
            guard end.roundedTime >= 0 else {
                throw AnalysisError.beforeMediaStart(option: "--to", time: end, file: path)
            }
            guard end.roundedTime <= duration.roundedTime else {
                throw AnalysisError.afterMediaEnd(option: "--to", time: end, file: path, end: duration)
            }
        }

        let file = MediaFile(path: path, probed: probed)
        let picture = Picture(name: path, source: .mediaFile(file), size: size)
        let found = try finder.area(form, in: picture, atMediaTime: time, place: Self.place, kind: Self.kind)
        let first = end.map { min(time, $0) } ?? 0
        let last = end.map { max(time, $0) } ?? duration
        let target = Quad(found.target)
        let frames = try tracker.track(
            target,
            in: file,
            atMediaTime: time,
            over: (file.frameTime(at: first) ?? first)...last
        )

        return TrackReport(track: Track(target: target, mediaTime: time, frames: frames))
    }

    // MARK: - Private
    // The area as JSON text, read and checked as a document's area is, so a message names `--area`.
    private func area(_ text: String) throws -> AreaForm {
        let value = try JSONReader(file: Self.place.description).read(text)
        try checker.check(value, as: .area, place: Self.place, kind: Self.kind)

        return AreaForm(value: value) ?? .rectangle(Rectangle(x: 0, y: 0, width: 0, height: 0))
    }
}
