//
//  StyledGlyph.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A shaped glyph with the face it was set in, and the run it belongs to: its index among the text's runs, its
// character style and the style's own face. Its offset is into its whole paragraph, and `isSpace` says the scalar it
// starts at is white space, which hangs at a line's end. `clusterCount` is the number of grapheme clusters that end in
// it, `tracking` the space added after it at the run's static tracking, in output pixels, and `widestTracking` at the
// widest tracking the run takes, once for each of those clusters.
struct StyledGlyph: Equatable, Sendable {
    // MARK: - Property
    let glyph: ShapedGlyph
    let isSpace: Bool
    let face: FontFace
    let source: Int
    let style: CharacterStyle
    let runFace: FontFace
    let clusterCount: Int
    let tracking: Double
    let widestTracking: Double

    // MARK: - Initializer
    init(
        glyph: ShapedGlyph,
        isSpace: Bool,
        face: FontFace,
        source: Int,
        style: CharacterStyle,
        runFace: FontFace,
        clusterCount: Int,
        tracking: Double,
        widestTracking: Double
    ) {
        self.glyph = glyph
        self.isSpace = isSpace
        self.face = face
        self.source = source
        self.style = style
        self.runFace = runFace
        self.clusterCount = clusterCount
        self.tracking = tracking
        self.widestTracking = widestTracking
    }

    // MARK: - Public
    // MARK: - Private
}
