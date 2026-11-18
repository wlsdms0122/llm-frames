//
//  FontFinder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Chooses a character style's face: the first family in its font list that its pack carries or the machine has
// installed, in the style's weight. A pack's fonts come before the machine's.
struct FontFinder: Sendable {
    // MARK: - Property
    private let shaper: any ShapingProvider
    private let library: ReferenceLibrary

    // MARK: - Initializer
    init(
        shaper: any ShapingProvider,
        library: ReferenceLibrary
    ) {
        self.shaper = shaper
        self.library = library
    }

    // MARK: - Public
    // `place` is where the font list was written, which a stop names.
    func face(
        for style: CharacterStyle,
        place: Place
    ) throws -> FontFace {
        let packFiles = try style.pack.map { try library.fontFiles(inPack: $0) } ?? []

        for family in style.families {
            if !packFiles.isEmpty, let face = shaper.face(family: family, weight: style.weight, in: packFiles) {
                return face
            }
            if let face = shaper.installedFace(family: family, weight: style.weight) {
                return face
            }
        }

        throw TextError.noFontFamily(place: place, kind: "theme", families: style.families, weight: style.weight)
    }

    // MARK: - Private
}
