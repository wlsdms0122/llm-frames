//
//  PresetValueResolver.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Resolves the names a preset holds to the values a resolved document carries: a LUT, matte or cover file to its
// absolute path. A preset names files as anything outside it does, so a pack's preset finds its pack's files by
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
        place: Place,
        kind: PlaceKind
    ) throws -> FilterOperation {
        switch operation {
        case let .lut(file, amount):
            .lut(file: try self.file(file, found: library.lutFile(named: file), place: place, kind: kind), amount: amount)

        case .exposure, .contrast, .saturation, .temperature, .hue, .sepia, .levels, .blur, .sharpen, .bloom,
            .vignette, .pixelate, .grain:
            operation
        }
    }

    func transition(
        _ preset: TransitionPreset,
        place: Place,
        kind: PlaceKind
    ) throws -> TransitionPreset {
        let cover = try preset.cover.map { cover in
            switch cover.source {
            case .color:
                cover

            case let .media(media):
                Cover(source: .media(try mediaFile(media, place: place, kind: kind)), span: cover.span)
            }
        }
        let matte = try preset.matte.map { matte in
            Matte(
                media: try mediaFile(matte.media, place: place, kind: kind),
                softness: matte.softness,
                isInverted: matte.isInverted,
                ease: matte.ease
            )
        }

        return TransitionPreset(
            description: preset.description,
            seconds: preset.seconds,
            over: preset.over,
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
