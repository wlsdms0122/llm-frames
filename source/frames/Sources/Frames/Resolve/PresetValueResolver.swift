//
//  PresetValueResolver.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Resolves the names a preset holds to the values a resolved document carries: a LUT, displacement map, impulse
// response, matte or cover file to its absolute path, and a theme colour to its value in the theme where the preset is
// chosen. A preset names files as anything outside it does, so a pack's preset finds its pack's files by
// `<pack>/<name>` wherever the pack is installed, and an absolute path stays as it is.
struct PresetValueResolver: Sendable {
    // MARK: - Property
    private let library: ReferenceLibrary

    // MARK: - Initializer
    init(library: ReferenceLibrary) {
        self.library = library
    }

    // MARK: - Public
    // `place` is where the preset is chosen.
    func operation(
        _ operation: FilterOperation,
        theme: MergedTheme,
        place: Place,
        kind: PlaceKind
    ) throws -> FilterOperation {
        switch operation {
        case let .lut(file, amount, space):
            .lut(file: try lutFile(file, place: place, kind: kind), amount: amount, space: space)

        case let .displace(file, amount, offset):
            .displace(file: try displacementMap(file, place: place, kind: kind), amount: amount, offset: offset)

        case let .bloom(amount, radius, color):
            .bloom(
                amount: amount,
                radius: radius,
                color: try color.map { try theme.presetColor($0, place: place, kind: kind) }
            )

        case .exposure, .contrast, .saturation, .temperature, .hue, .sepia, .levels, .blur, .sharpen, .vignette,
            .pixelate, .grain:
            operation
        }
    }

    func lutFile(
        _ name: String,
        place: Place,
        kind: PlaceKind
    ) throws -> String {
        try file(name, found: library.lutFile(named: name), place: place, kind: kind)
    }

    // A displacement map is named as media is, and is a raster still read as its tags say.
    func displacementMap(
        _ name: String,
        place: Place,
        kind: PlaceKind
    ) throws -> String {
        let path = try mediaFile(name, place: place, kind: kind)
        if let refusal = try refusal(ofDisplacementMap: path, reference: name, place: place, kind: kind) {
            throw ResolveError.unusableDisplacementMap(place: place, kind: kind, reference: name, refusal: refusal)
        }

        return path
    }

    // An impulse response is named as media is, and is sound of at least one sample and at most 30 seconds.
    func impulseResponse(
        _ name: String,
        place: Place,
        kind: PlaceKind
    ) throws -> String {
        let path = try mediaFile(name, place: place, kind: kind)
        if let refusal = try refusal(ofImpulseResponse: path, reference: name, place: place, kind: kind) {
            throw ResolveError.unusableImpulseResponse(place: place, kind: kind, reference: name, refusal: refusal)
        }

        return path
    }

    func transition(
        _ preset: TransitionPreset,
        theme: MergedTheme,
        place: Place,
        kind: PlaceKind
    ) throws -> TransitionPreset {
        let cover = try preset.cover.map { cover in
            switch cover.source {
            case let .color(color):
                Cover(source: .color(try theme.presetColor(color, place: place, kind: kind)), span: cover.span)

            case let .media(media):
                Cover(
                    source: .media(try mediaFile(media, place: place, kind: kind)),
                    colorSpace: cover.colorSpace,
                    span: cover.span
                )

            case let .page(media, page):
                Cover(
                    source: .page(try mediaFile(media, place: place, kind: kind), page: page),
                    colorSpace: cover.colorSpace,
                    span: cover.span
                )
            }
        }
        let matte = try preset.matte.map { matte in
            Matte(
                media: try mediaFile(matte.media, place: place, kind: kind),
                page: matte.page,
                colorSpace: matte.colorSpace,
                softness: matte.softness,
                isInverted: matte.isInverted,
                ease: matte.ease
            )
        }

        return TransitionPreset(
            description: preset.description,
            seconds: preset.seconds,
            over: preset.over,
            audio: preset.audio,
            incoming: preset.incoming,
            outgoing: preset.outgoing,
            cover: cover,
            matte: matte
        )
    }

    // MARK: - Private
    private func mediaFile(
        _ name: String,
        place: Place,
        kind: PlaceKind
    ) throws -> String {
        try file(name, found: library.mediaFile(named: name), place: place, kind: kind)
    }

    // A document is a sequence whatever it holds.
    private func refusal(
        ofDisplacementMap path: String,
        reference: String,
        place: Place,
        kind: PlaceKind
    ) throws -> DisplacementMapRefusal? {
        guard !library.isDocument(reference) else { return .sequence }
        guard let medium = try probedMedium(of: path, reference: reference, place: place, kind: kind) else {
            return .imageSequence
        }
        guard case let .media(media) = medium else { return .page }

        switch media.kind {
        case .image:
            guard let reading = media.colorSpace?.reading, !reading.converts(in: nil) else { return nil }

            return .unconvertibleColor

        case .video:
            return .video

        case .page:
            return .page

        case .sequence:
            return .sequence

        case .audio:
            return .sound
        }
    }

    // A document is a sequence whatever it holds. The sound's length is the duration its probe gives, which for a
    // video is the file's.
    private func refusal(
        ofImpulseResponse path: String,
        reference: String,
        place: Place,
        kind: PlaceKind
    ) throws -> ImpulseResponseRefusal? {
        guard !library.isDocument(reference) else { return .sequence }
        guard let medium = try probedMedium(of: path, reference: reference, place: place, kind: kind) else {
            return .imageSequence
        }
        guard case let .media(media) = medium else { return .page }

        switch media.kind {
        case .image, .video, .audio:
            guard media.hasSound else { return .noSound }
            guard media.duration > 0 else { return .noSamples }
            guard media.duration <= 30 else { return .tooLong(duration: media.duration) }

            return nil

        case .page:
            return .page

        case .sequence:
            return .sequence
        }
    }

    // What the probe finds at a path named as media, nil for an image sequence's directory: a directory is no media
    // file, so where the probe finds none there, an image sequence's probe tells it.
    private func probedMedium(
        of path: String,
        reference: String,
        place: Place,
        kind: PlaceKind
    ) throws -> ProbedMedium? {
        let probed = Result { try library.mediaFacts.probedMedium(of: path) }
        guard case let .success(medium?) = probed else {
            if (try? library.mediaFacts.probedImageSequence(at: path)) != nil { return nil }
            if case let .failure(error) = probed {
                throw ResolveError.unreadableMedia(place: place, kind: kind, reference: reference, reason: "\(error)")
            }

            throw ResolveError.missingMedia(place: place, kind: kind, reference: reference)
        }

        return medium
    }

    // A bare name, an unknown pack or another spelling names no file, and stops.
    private func file(
        _ name: String,
        found: String?,
        place: Place,
        kind: PlaceKind
    ) throws -> String {
        guard let found else { throw ResolveError.unknownPresetFile(place: place, kind: kind, name: name) }

        return found
    }
}
