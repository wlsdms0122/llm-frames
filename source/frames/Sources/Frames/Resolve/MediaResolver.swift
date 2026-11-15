//
//  MediaResolver.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Turns the media a document names into what time knows of it: the probed facts of a file, the length and frames an
// image sequence's rate gives, and the time plan of a compound clip, a document named by its file or a template
// instance. Media named by `<pack>/<file>` is found through the library before it is probed.
struct MediaResolver: Sendable {
    // MARK: - Property
    private let mediaFacts: any MediaFactProvider
    private let presets: any PresetProvider
    private let library: ReferenceLibrary
    private let instantiator: TemplateInstantiator

    // MARK: - Initializer
    init(
        mediaFacts: any MediaFactProvider,
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        self.mediaFacts = mediaFacts
        self.presets = presets
        self.library = library
        self.instantiator = TemplateInstantiator(mediaKinds: library)
    }

    // MARK: - Public
    // `theme` is the theme in effect where the media is written, which a nested document's own theme merges over.
    func media(
        of source: MediaSource,
        place: Place,
        kind: PlaceKind,
        theme: MergedTheme
    ) throws -> ResolvedMedia {
        switch source {
        case let .file(reference) where library.isDocument(reference):
            return try document(named: reference, place: place, kind: kind, theme: theme)

        case let .file(reference):
            guard
                let file = try library.mediaFile(named: reference),
                let probed = mediaFacts.probedMedia(of: file)
            else {
                throw ResolveError.unprobedMedia(place: place, kind: kind, reference: reference)
            }

            return ResolvedMedia(
                kind: probed.kind,
                reference: reference,
                file: file,
                duration: probed.duration,
                fps: probed.fps,
                frames: frames(of: probed)
            )

        case let .imageSequence(reference, fps):
            guard
                let directory = try library.mediaFile(named: reference),
                let count = mediaFacts.frameCount(ofImageSequence: directory)
            else {
                throw ResolveError.unprobedMedia(place: place, kind: kind, reference: reference)
            }

            // Its media seconds are frame index / fps, so its last frame starts one frame before its end.
            let duration = Double(count) / fps
            return ResolvedMedia(
                kind: .video,
                reference: reference,
                file: directory,
                duration: duration,
                fps: fps,
                frames: 0...max(duration - 1 / fps, 0)
            )

        case let .compound(document):
            return nested(try planner(library: library).plan(document, theme: theme), reference: nil)

        case .document:
            return ResolvedMedia(kind: .image, reference: nil, file: nil, duration: 0)

        case let .template(name, arguments, argumentThemes):
            return try instance(
                of: name,
                arguments: arguments,
                argumentThemes: argumentThemes,
                place: place,
                kind: kind,
                theme: theme
            )

        case let .argument(source, argumentTheme):
            return try media(of: source, place: place, kind: kind, theme: argumentTheme)
        }
    }

    // MARK: - Private
    // A document named by its file stands as if written there, so it starts from the theme in effect there. What it
    // holds is read on the way through its file, so media that holds the document again stops.
    private func document(
        named reference: String,
        place: Place,
        kind: PlaceKind,
        theme: MergedTheme
    ) throws -> ResolvedMedia {
        guard let document = try library.document(named: reference) else {
            throw ResolveError.unprobedMedia(place: place, kind: kind, reference: reference)
        }
        guard document.kind == .sequence else {
            return ResolvedMedia(kind: .image, reference: reference, file: nil, duration: 0)
        }

        let inner = try library.reading(file: document.file, name: reference)
        let sequence = SequenceReader().sequence(from: document.value, place: place)
        return nested(try planner(library: inner).plan(sequence, theme: theme), reference: reference)
    }

    // A template resolves on the base theme and its own, so only its arguments change it. Media it was given keeps
    // `theme`, the theme where the instance is written, unless it is passed on from a template that was given it,
    // where it keeps the theme of the document that wrote it.
    private func instance(
        of name: String,
        arguments: JSONObject,
        argumentThemes: [String: MergedTheme],
        place: Place,
        kind: PlaceKind,
        theme: MergedTheme
    ) throws -> ResolvedMedia {
        guard let template = try library.template(named: name) else {
            throw ModelError.unknownTemplate(place: place.appending(key: "template"), kind: kind.label, name: name)
        }

        let instance = try instantiator.instance(
            of: template,
            arguments: arguments,
            place: place.appending(key: "args")
        )
        guard instance.kind == .sequence else {
            return ResolvedMedia(kind: .image, reference: nil, file: nil, duration: 0)
        }

        let themes = Dictionary(
            instance.arguments.map { argument in
                (place.appending(argument.place), argumentThemes[argument.name] ?? theme)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let sequence = SequenceReader(arguments: themes).sequence(from: instance.document, place: place)
        return nested(try planner(library: library).plan(sequence, theme: .base), reference: nil)
    }

    // A nested sequence is evaluated at whatever time is asked, clamped into [0, duration).
    private func nested(
        _ plan: TimePlan,
        reference: String?
    ) -> ResolvedMedia {
        ResolvedMedia(
            kind: .sequence,
            reference: reference,
            file: nil,
            duration: plan.duration,
            frames: 0...plan.duration.nextDown,
            nested: plan
        )
    }

    // A planner holds a resolver, so the one for nested documents is made when it is needed.
    private func planner(library: ReferenceLibrary) -> TimePlanner {
        TimePlanner(mediaFacts: mediaFacts, presets: presets, library: library)
    }

    private func frames(of probed: ProbedMedia) -> ClosedRange<Double>? {
        guard probed.kind == .video else { return nil }
        guard let first = probed.frames.first, let last = probed.frames.last else { return 0...probed.duration }

        return first...last
    }
}
