//
//  MediaResolver.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Turns the media a document names into what time knows of it: the probed facts of a file, the length and frames an
// image sequence's rate gives, and the time plan of a compound clip.
struct MediaResolver: Sendable {
    // MARK: - Property
    private let mediaFacts: any MediaFactProvider
    private let presets: any PresetProvider

    // MARK: - Initializer
    init(
        mediaFacts: any MediaFactProvider,
        presets: any PresetProvider
    ) {
        self.mediaFacts = mediaFacts
        self.presets = presets
    }

    // MARK: - Public
    // `theme` is the theme in effect where the media is written, which a compound clip's own theme merges over.
    func media(
        of source: MediaSource,
        place: Place,
        kind: PlaceKind,
        theme: JSONValue
    ) throws -> ResolvedMedia {
        switch source {
        case let .file(file):
            guard let probed = mediaFacts.probedMedia(of: file) else {
                throw ResolveError.unprobedMedia(place: place, kind: kind, reference: file)
            }
            // A document named by its path is read with packs and templates, before time is planned.
            guard probed.kind != .sequence else {
                throw ResolveError.unreadReference(place: place, kind: kind, reference: file)
            }

            return ResolvedMedia(
                kind: probed.kind,
                file: file,
                duration: probed.duration,
                fps: probed.fps,
                frames: frames(of: probed)
            )

        case let .imageSequence(directory, fps):
            guard let count = mediaFacts.frameCount(ofImageSequence: directory) else {
                throw ResolveError.unprobedMedia(place: place, kind: kind, reference: directory)
            }

            // Its media seconds are frame index / fps, so its last frame starts one frame before its end.
            let duration = Double(count) / fps
            return ResolvedMedia(
                kind: .video,
                file: directory,
                duration: duration,
                fps: fps,
                frames: 0...max(duration - 1 / fps, 0)
            )

        case let .compound(document):
            let nested = try TimePlanner(mediaFacts: mediaFacts, presets: presets).plan(document, theme: theme)
            // A compound clip is evaluated at whatever time is asked, clamped into [0, duration).
            return ResolvedMedia(
                kind: .sequence,
                file: nil,
                duration: nested.duration,
                frames: 0...nested.duration.nextDown,
                nested: nested
            )

        case .document:
            return ResolvedMedia(kind: .image, file: nil, duration: 0)

        case let .template(name), let .parameter(name):
            throw ResolveError.unreadReference(place: place, kind: kind, reference: name)
        }
    }

    // MARK: - Private
    private func frames(of probed: ProbedMedia) -> ClosedRange<Double>? {
        guard probed.kind == .video else { return nil }
        guard let first = probed.frames.first, let last = probed.frames.last else { return 0...probed.duration }

        return first...last
    }
}
