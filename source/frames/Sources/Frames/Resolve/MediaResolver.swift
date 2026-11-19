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
    private let optionChecker: ChoiceOptionChecker
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
        self.optionChecker = ChoiceOptionChecker(presets: presets, library: library)
        self.instantiator = TemplateInstantiator(mediaKinds: library)
    }

    // MARK: - Public
    // `theme` is the theme in effect where the media is written, which a nested document's own theme merges over, and
    // `colorSpace` the one written there for its pictures. A picture no fixed formula converts stops where no
    // `colorSpace` is written for it (FRAMES-26 Media).
    func media(
        of source: MediaSource,
        place: Place,
        kind: PlaceKind,
        theme: MergedTheme,
        colorSpace: ColorSpace?
    ) throws -> MediaPlan {
        switch source {
        case let .file(reference) where library.isDocument(reference):
            return try document(named: reference, place: place, kind: kind, theme: theme)

        case let .file(reference):
            guard
                let file = try library.mediaFile(named: reference),
                let probed = try probed(place: place, kind: kind, reference: reference, {
                    try mediaFacts.probedMedia(of: file)
                })
            else {
                throw ResolveError.missingMedia(place: place, kind: kind, reference: reference)
            }
            try checkColor(
                of: probed.colorSpace,
                colorSpace: colorSpace,
                place: place,
                kind: kind,
                reference: reference
            )

            return MediaPlan(
                kind: probed.kind,
                reference: reference,
                source: .file(MediaFile(path: file, probed: probed)),
                duration: probed.duration,
                hasSound: probed.hasSound
            )

        case let .imageSequence(reference, fps):
            guard
                let directory = try library.mediaFile(named: reference),
                let probed = try probed(place: place, kind: kind, reference: reference, {
                    try mediaFacts.probedImageSequence(at: directory)
                })
            else {
                throw ResolveError.missingMedia(place: place, kind: kind, reference: reference)
            }
            try checkColor(
                of: probed.colorSpace,
                colorSpace: colorSpace,
                place: place,
                kind: kind,
                reference: reference
            )

            // Its media seconds are frame index / fps, so its last frame starts one frame before its end.
            let duration = Double(probed.files.count) / fps
            let file = MediaFile(
                path: directory,
                fps: fps,
                size: probed.size,
                frameTimes: probed.files.indices.map { Double($0) / fps },
                frameFiles: probed.files,
                taggedColorSpace: probed.colorSpace?.name
            )
            return MediaPlan(
                kind: .video,
                reference: reference,
                source: .file(file),
                duration: duration
            )

        case let .compound(document):
            return nested(try planner(library: library).plan(document, theme: theme), reference: nil)

        case let .template(name, arguments, passedOnThemes):
            return try instance(
                of: name,
                arguments: arguments,
                passedOnThemes: passedOnThemes,
                place: place,
                kind: kind,
                theme: theme
            )

        case let .argument(source, argumentTheme):
            return try media(of: source, place: place, kind: kind, theme: argumentTheme, colorSpace: colorSpace)
        }
    }

    // A transition's cover or matte file, by the absolute path its preset was resolved to, with the `colorSpace` its
    // preset writes for it. A preset names a file, so it is never an image sequence or a document.
    func transitionMedia(
        at path: String,
        place: Place,
        kind: PlaceKind,
        colorSpace: ColorSpace?
    ) throws -> TransitionMedia {
        guard
            let probed = try probed(place: place, kind: kind, reference: path, { try mediaFacts.probedMedia(of: path) })
        else {
            throw ResolveError.missingMedia(place: place, kind: kind, reference: path)
        }
        try checkColor(of: probed.colorSpace, colorSpace: colorSpace, place: place, kind: kind, reference: path)

        return TransitionMedia(
            file: MediaFile(path: path, probed: probed),
            duration: probed.duration
        )
    }

    // MARK: - Private
    // A document named by its file stands as if written there, so it starts from the theme in effect there. What it
    // holds is read on the way through its file, so media that holds the document again stops.
    private func document(
        named reference: String,
        place: Place,
        kind: PlaceKind,
        theme: MergedTheme
    ) throws -> MediaPlan {
        guard let document = try library.document(named: reference) else {
            throw ResolveError.missingMedia(place: place, kind: kind, reference: reference)
        }
        let inner = try library.reading(file: document.file, name: reference)
        let sequence = SequenceReader().sequence(from: document.value, place: place)
        return nested(try planner(library: inner).plan(sequence, theme: theme), reference: reference)
    }

    // A template resolves on the base theme and its own, so only its arguments change it. Media it was given keeps
    // `theme`, the theme where the instance is written, unless it is passed on from a template that was given it,
    // where it keeps the theme of the document that wrote it. An instance plans the same each time, so one that holds
    // the same template with the same values again would never end.
    private func instance(
        of name: String,
        arguments: JSONObject,
        passedOnThemes: PassedOnThemeTable,
        place: Place,
        kind: PlaceKind,
        theme: MergedTheme
    ) throws -> MediaPlan {
        guard let template = try library.template(named: name) else {
            throw ModelError.unknownTemplate(place: place.appending(key: "template"), kind: kind.label, name: name)
        }

        try optionChecker.check(template)
        let instance = try instantiator.instance(
            of: template,
            arguments: arguments,
            place: place.appending(key: "args")
        )
        let inner = try library.reading(instanceOf: name, values: instance.values)
        let argumentThemes = ArgumentThemeTable(
            instance: instance,
            place: place,
            theme: theme,
            passedOnThemes: passedOnThemes
        )
        let sequence = SequenceReader(argumentThemes: argumentThemes).sequence(from: instance.document, place: place)
        return nested(try planner(library: inner).plan(sequence, theme: .base), reference: nil)
    }

    // A nested sequence is evaluated at whatever time is asked, clamped into [0, duration). It plays sound when any of
    // its clips does.
    private func nested(
        _ plan: TimePlan,
        reference: String?
    ) -> MediaPlan {
        let media = plan.storyline.map(\.source.media) + plan.clips.map(\.media)

        return MediaPlan(
            kind: .sequence,
            reference: reference,
            source: .sequence(plan),
            duration: plan.duration,
            hasSound: media.contains { $0?.hasSound ?? false }
        )
    }

    // A planner holds a resolver, so the one for nested documents is made when it is needed.
    private func planner(library: ReferenceLibrary) -> TimePlanner {
        TimePlanner(mediaFacts: mediaFacts, presets: presets, library: library)
    }

    // A picture only the platform's colour management reads stops at the place that names it, unless that place writes
    // the colour space it is read in.
    private func checkColor(
        of probed: ProbedColorSpace?,
        colorSpace: ColorSpace?,
        place: Place,
        kind: PlaceKind,
        reference: String
    ) throws {
        guard colorSpace == nil, probed?.reading == .platform else { return }

        throw ResolveError.unconvertibleMediaColor(place: place, kind: kind, reference: reference)
    }

    // What the probe gives, a failure of it stopping at the place the media is named.
    private func probed<Facts>(
        place: Place,
        kind: PlaceKind,
        reference: String,
        _ probe: () throws -> Facts?
    ) throws -> Facts? {
        try Result(catching: probe)
            .mapError { ResolveError.unreadableMedia(place: place, kind: kind, reference: reference, reason: "\($0)") }
            .get()
    }
}
