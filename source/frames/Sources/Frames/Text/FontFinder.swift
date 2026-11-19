//
//  FontFinder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Chooses the faces a character style's text is set in: for each family in its font list that its pack carries or
// the machine has installed, in order, the face font matching gives for the style's weight and italic. The first is
// the style's face and the rest take the characters it lacks. A pack's fonts come before the machine's.
struct FontFinder: Sendable {
    // MARK: - Property
    private let shaper: any ShapingProvider
    private let library: ReferenceLibrary
    private let matcher = FaceMatcher()

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
    func faces(
        for style: CharacterStyle,
        place: Place
    ) throws -> [FontFace] {
        let packFiles = try style.pack.map { try library.fontFiles(inPack: $0) } ?? []
        let faces = style.families.compactMap { family in
            let packed = packFiles.isEmpty ? [] : shaper.faces(family: family, in: packFiles)
            let family = packed.isEmpty ? shaper.installedFaces(family: family) : packed

            return matcher.face(among: family, weight: style.weight, italic: style.italic)
        }
        guard !faces.isEmpty else {
            throw TextError.noFontFamily(place: place, kind: "theme", families: style.families)
        }

        return faces
    }

    // MARK: - Private
}
