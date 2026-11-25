//
//  TrackReporter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Follows a target in a video or an image sequence from media time `--at` with the tracker provider, and reports it as
// the track data `track` prints (FRAMES-23). The target is JSON text, a rectangle in a document's rect area form or a
// quadrilateral in a corner pin's order, which a tracker that follows perspective follows as a plane. It is followed
// over the whole medium, or over the frames shown from `--at` to `--to`, either way. A directory is an image sequence,
// read as a video at the rate `fps` gives it. The medium is read in `colorSpace` where `--color-space` names one. A
// target followed on no frame stops, since track data names the frame at `--at`.
package struct TrackReporter: Sendable {
    // MARK: - Property
    private static let areaPlace = Place(components: [.key("--area")])
    private static let quadPlace = Place(components: [.key("--quad")])

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
        fps: Double? = nil,
        target: TrackTarget,
        at time: Double,
        to end: Double? = nil,
        colorSpace: ColorSpace? = nil
    ) throws -> TrackReport {
        let (quad, place, kind) = try self.quad(of: target)
        let (file, duration) = try media(of: try MediaArgument(path: path, fps: fps))
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

        let first = end.map { min(time, $0) } ?? 0
        let last = end.map { max(time, $0) } ?? duration
        let range = (file.frameTime(at: first) ?? first)...last
        let frames = try Result {
            try follower.follow(quad, in: file, atMediaTime: time, over: range, colorSpace: colorSpace)
        }
        .mapError { error in
            ProviderError.failed(
                provider: .tracker,
                place: place,
                kind: kind,
                picture: ProviderPicture(media: path, mediaTime: time),
                message: "\(error)"
            )
        }
        .get()
        guard !frames.isEmpty else {
            throw AnalysisError.targetNotFollowed(option: place.description, time: time, file: path)
        }

        return TrackReport(time: time, frames: frames)
    }

    // MARK: - Private
    // The frames followed and the medium's duration: a video's, or an image sequence's at its rate.
    private func media(of argument: MediaArgument) throws -> (file: MediaFile, duration: Double) {
        switch argument {
        case let .imageSequence(directory, fps):
            guard let probed = try mediaFacts.probedImageSequence(at: directory) else {
                throw AnalysisError.missingMedia(file: directory)
            }
            let sequence = ImageSequence(probed: probed, directory: directory, fps: fps)

            return (sequence.file, sequence.duration)

        case let .file(path):
            guard let medium = try mediaFacts.probedMedium(of: path) else {
                throw AnalysisError.missingMedia(file: path)
            }
            guard case let .media(probed) = medium, probed.kind == .video else {
                throw AnalysisError.notVideo(file: path, kind: medium.kind)
            }

            return (MediaFile(path: path, probed: probed), probed.duration)
        }
    }

    // The target's quadrilateral, and the option that gives it and the kind of value it is, which its messages name.
    private func quad(of target: TrackTarget) throws -> (quad: Quad, place: Place, kind: String) {
        switch target {
        case let .area(text):
            (Quad(try area(text)), Self.areaPlace, "area")

        case let .quad(text):
            (try quad(text), Self.quadPlace, "quad")
        }
    }

    // The rectangle as JSON text, read and checked as a document's area is, so a message names `--area`. A clip area
    // stops, since there is no clip to name.
    private func area(_ text: String) throws -> Rectangle {
        let value = try JSONReader(file: Self.areaPlace.description).read(text)
        try checker.check(value, as: .area, place: Self.areaPlace, kind: "area")

        return try (AreaForm(value: value) ?? .rectangle(Rectangle(x: 0, y: 0, width: 0, height: 0)))
            .rectangle(place: Self.areaPlace, kind: "area")
    }

    // The quadrilateral as JSON text, four points of two numbers in a corner pin's order, strictly convex, since a
    // tracker follows it as a plane.
    private func quad(_ text: String) throws -> Quad {
        let value = try JSONReader(file: Self.quadPlace.description).read(text)
        guard let items = value.arrayValue, items.count == 4 else { throw AnalysisError.quadForm }

        let points = try items.map { item in
            guard
                let numbers = item.arrayValue,
                numbers.count == 2,
                let x = numbers[0].numberValue,
                let y = numbers[1].numberValue
            else {
                throw AnalysisError.quadForm
            }

            return Point(x: x, y: y)
        }
        let quad = Quad(topLeft: points[0], topRight: points[1], bottomRight: points[2], bottomLeft: points[3])
        guard quad.orientation != nil else { throw AnalysisError.quadNotConvex }

        return quad
    }
}
