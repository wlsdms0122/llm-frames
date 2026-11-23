//
//  StyledGlyph.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A shaped glyph with the face it was set in, whether it is turned 90 degrees clockwise in a vertical line, the
// horizontal scale it is narrowed by along its own horizontal axis, and the run it belongs to: its index among the
// text's runs, its character style and the style's own face. Its offset is into its whole paragraph. A glyph of a
// horizontal-in-vertical composition is set on the line: it lies at the composition's pen, its placement offset holds
// its place in the composition's square, and the composition's last glyph moves the pen by the composition's advance.
struct StyledGlyph: Equatable, Sendable {
    // MARK: - Property
    let glyph: ShapedGlyph
    let face: FontFace
    let isSideways: Bool
    let horizontalScale: Double
    let source: Int
    let style: CharacterStyle
    let runFace: FontFace

    // MARK: - Initializer
    init(
        glyph: ShapedGlyph,
        face: FontFace,
        isSideways: Bool,
        horizontalScale: Double,
        source: Int,
        style: CharacterStyle,
        runFace: FontFace
    ) {
        self.glyph = glyph
        self.face = face
        self.isSideways = isSideways
        self.horizontalScale = horizontalScale
        self.source = source
        self.style = style
        self.runFace = runFace
    }

    // MARK: - Public
    // MARK: - Private
}
