//
//  MediaResolver.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Turns the media a document names into what time knows of it: the probed facts of a file or a page of a PDF, the
// length and frames an image sequence's rate gives, and the time plan of a compound clip, a document named by its file
// or a template instance. Media named by `<pack>/<file>` is found through the library before it is probed.
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
    // `theme` is the theme in effect where the media is written, which a nested document's own theme merges over.
    func media(
        of source: MediaSource,
        place: Place,
        kind: PlaceKind,
        theme: MergedTheme
    ) throws -> MediaPlan {
        switch source {
        case let .file(reference) where library.isDocument(reference):
            return try document(named: reference, place: place, kind: kind, theme: theme)

        case let .file(reference):
            guard let file = try library.mediaFile(named: reference) else {
                throw ResolveError.missingMedia(place: place, kind: kind, reference: reference)
            }
            switch try medium(at: file, place: place, kind: kind, reference: reference) {
            case let .pdf(pageCount):
                // A PDF of one page named as a file is that page.
                return pagePlan(
                    try pageFile(at: file, page: nil, of: pageCount, place: place, kind: kind, reference: reference),
                    reference: reference
                )

            case let .media(probed):
                return MediaPlan(
                    kind: probed.kind,
                    reference: reference,
                    source: .file(MediaFile(path: file, probed: probed)),
                    duration: probed.duration,
                    hasSound: probed.hasSound
                )
            }

        case let .imageSequence(reference, fps):
            guard
                let directory = try library.mediaFile(named: reference),
                let probed = try probed(place: place, kind: kind, reference: reference, {
                    try mediaFacts.probedImageSequence(at: directory)
                })
            else {
                throw ResolveError.missingMedia(place: place, kind: kind, reference: reference)
            }
            let file = MediaFile(imageSequence: probed, in: directory, fps: fps)
            return MediaPlan(
                kind: .video,
                reference: reference,
                source: .file(file),
                duration: file.imageSequenceDuration
            )

        case let .page(reference, page):
            guard let file = try library.mediaFile(named: reference) else {
                throw ResolveError.missingMedia(place: place, kind: kind, reference: reference)
            }
            guard case let .pdf(pageCount) = try medium(at: file, place: place, kind: kind, reference: reference) else {
                throw ModelError.pageOfNonPDF(place: place, kind: kind.label, reference: reference)
            }

            return pagePlan(
                try pageFile(at: file, page: page, of: pageCount, place: place, kind: kind, reference: reference),
                reference: reference
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
            return try media(of: source, place: place, kind: kind, theme: argumentTheme)
        }
    }

    // How the clip at `place` in `clipPlace` reads `media` by what it writes. A page takes no `toneMap` and only a
    // `colorSpace` of standard dynamic range, and a picture only the platform's colour management reads stops unless
    // the clip writes the colour space it is read in (FRAMES-26 Media). A nested sequence's own clips are checked where
    // they are planned.
    func checkReading(
        of media: MediaPlan,
        by clipMedia: ClipMedia,
        clip place: Place,
        in clipPlace: ClipPlace
    ) throws {
        guard case let .file(file) = media.source else { return }

        switch file.pageRefusal(colorSpace: clipMedia.colorSpace, isToneMapped: clipMedia.isToneMapped) {
        case .toneMap:
            let table = ClipKeyTable.table(for: .media(media.kind), in: clipPlace)
            throw ModelError.unknownKey(
                place: place,
                kind: table.kind,
                key: "toneMap",
                allowed: table.keys.filter { $0 != "toneMap" }
            )

        case let .colorSpace(colorSpace):
            throw ModelError.unknownValue(
                place: place.appending(key: "colorSpace"),
                kind: ClipKind.media(media.kind).label,
                value: colorSpace.rawValue,
                allowed: VocabularyTable.standardDynamicRangeColorSpaces
            )

        case nil:
            try checkColor(
                of: file.colorReading,
                colorSpace: clipMedia.colorSpace,
                place: place.appending(key: "media"),
                kind: .genericClip(clipPlace),
                reference: media.reference ?? file.path
            )
        }
    }

    // A transition's cover or matte file, by the absolute path its preset was resolved to, with the page of a PDF and
    // the `colorSpace` its preset writes for it. A preset names a file, so it is never an image sequence or a document.
    // A transition always reads its picture, so its colour is checked here. No key check probes a preset's media, so
    // the stops of a page come here (FRAMES-3 PDF pages), a `colorSpace` of HDR range on a page among them.
    func transitionMedia(
        at path: String,
        page: Int?,
        place: Place,
        kind: PlaceKind,
        colorSpace: ColorSpace?
    ) throws -> TransitionMedia {
        switch try medium(at: path, place: place, kind: kind, reference: path) {
        case let .pdf(pageCount):
            let file = try pageFile(at: path, page: page, of: pageCount, place: place, kind: kind, reference: path)
            if let refused = file.pageRefusedColorSpace(colorSpace), let page = file.page {
                throw ModelError.highDynamicRangePage(
                    place: place,
                    kind: kind.label,
                    reference: path,
                    page: page,
                    colorSpace: refused
                )
            }

            return TransitionMedia(file: file, duration: 0)

        case let .media(probed):
            guard page == nil else { throw ModelError.pageOfNonPDF(place: place, kind: kind.label, reference: path) }
            try checkColor(
                of: probed.colorSpace?.reading,
                colorSpace: colorSpace,
                place: place,
                kind: kind,
                reference: path
            )

            return TransitionMedia(
                file: MediaFile(path: path, probed: probed),
                duration: probed.duration
            )
        }
    }

    // MARK: - Private
    // A page is a still, of no length and no sound.
    private func pagePlan(
        _ file: MediaFile,
        reference: String
    ) -> MediaPlan {
        MediaPlan(kind: .page, reference: reference, source: .file(file), duration: 0)
    }

    // What the file at `path` is. A file that is not there stops, and so does one the probe cannot read, with why.
    private func medium(
        at path: String,
        place: Place,
        kind: PlaceKind,
        reference: String
    ) throws -> ProbedMedium {
        guard
            let medium = try probed(place: place, kind: kind, reference: reference, {
                try mediaFacts.probedMedium(of: path)
            })
        else {
            throw ResolveError.missingMedia(place: place, kind: kind, reference: reference)
        }

        return medium
    }

    // Page `page` of the PDF of `pageCount` pages at `path`, or where no page is written the one page of a PDF of one
    // page, checked by the probe's decoder. A page's untagged colour is `srgb`, which a written `colorSpace` replaces,
    // so every colour space converts it. A PDF of more pages named as a file and a page above its count stop (FRAMES-3
    // PDF pages).
    private func pageFile(
        at path: String,
        page: Int?,
        of pageCount: Int,
        place: Place,
        kind: PlaceKind,
        reference: String
    ) throws -> MediaFile {
        let number: Int
        switch PageChoice(page: page, pageCount: pageCount) {
        case let .page(chosen):
            number = chosen

        case let .unnamed(pageCount):
            throw ModelError.unnamedPage(place: place, kind: kind.label, reference: reference, pageCount: pageCount)

        case let .missing(page, pageCount):
            throw ModelError.missingPage(
                place: place,
                kind: kind.label,
                reference: reference,
                page: page,
                pageCount: pageCount
            )

        case .empty:
            throw ModelError.unreadableMedia(
                place: place,
                kind: kind.label,
                reference: reference,
                reason: PageChoice.emptyReason
            )
        }
        guard
            let probed = try probed(place: place, kind: kind, reference: reference, {
                try mediaFacts.probedPage(number, of: path)
            })
        else {
            throw ResolveError.missingMedia(place: place, kind: kind, reference: reference)
        }

        return MediaFile(path: path, size: probed.size, colorReading: .formulas(.srgb), page: number)
    }

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

    private func checkColor(
        of reading: ColorReading?,
        colorSpace: ColorSpace?,
        place: Place,
        kind: PlaceKind,
        reference: String
    ) throws {
        guard let reading, !reading.converts(in: colorSpace) else { return }

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
