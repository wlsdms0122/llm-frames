//
//  TrackReporter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Follows a rectangle in a video from media time `--at` with the tracker provider, as `track` on a clip does, and
// reports it as `track` prints it. The rectangle is JSON text in a document's rect area form. It is followed over the
// whole video, or over the frames shown from `--at` to `--to`, either way. The video is read in `colorSpace` where `--color-space` names one.
package struct TrackReporter: Sendable {
    // MARK: - Property
    private static let place = Place(components: [.key("--area")])
    private static let kind = "area"

    private let mediaFacts: any MediaFactProvider
    private let follower: TargetFollower
    private let checker = KeyChecker()

    // MARK: - Initializer
    package init(
        mediaFacts: any MediaFactProvider,
        tracker: any TrackerProvider
    ) {
        self.mediaFacts = mediaFacts
        self.follower = TargetFollower(tracker: tracker)
    }

    // MARK: - Public
    package func report(
        of path: String,
        area text: String,
        at time: Double,
        to end: Double? = nil,
        colorSpace: ColorSpace? = nil
    ) throws -> TrackReport {
        let target = try area(text)
        guard let medium = try mediaFacts.probedMedium(of: path) else { throw AnalysisError.missingMedia(file: path) }
        guard case let .media(probed) = medium, probed.kind == .video else {
            throw AnalysisError.notVideo(file: path, kind: medium.kind)
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
        let first = end.map { min(time, $0) } ?? 0
        let last = end.map { max(time, $0) } ?? duration
        let range = (file.frameTime(at: first) ?? first)...last
        let frames = try Result {
            try follower.follow(Quad(target), in: file, atMediaTime: time, over: range, colorSpace: colorSpace)
        }
        .mapError { error in
            ProviderError.failed(
                provider: .tracker,
                place: Self.place,
                kind: Self.kind,
                picture: ProviderPicture(media: path, mediaTime: time),
                message: "\(error)"
            )
        }
        .get()

        return TrackReport(track: Track(target: Quad(target), mediaTime: time, frames: frames))
    }

    // MARK: - Private
    // The rectangle as JSON text, read and checked as a document's area is, so a message names `--area`. A clip area
    // stops, since there is no clip to name.
    private func area(_ text: String) throws -> Rectangle {
        let value = try JSONReader(file: Self.place.description).read(text)
        try checker.check(value, as: .area, place: Self.place, kind: Self.kind)

        return try (AreaForm(value: value) ?? .rectangle(Rectangle(x: 0, y: 0, width: 0, height: 0)))
            .rectangle(place: Self.place, kind: Self.kind)
    }
}
