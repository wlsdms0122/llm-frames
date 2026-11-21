//
//  StyledCharacter.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A grapheme cluster of a paragraph as shaped: its range of the title's text in Unicode scalars, the run it is set in,
// its index among the text's runs, that run's character style and the style's own face, and the glyphs it owns, those
// of its group of glyphs when it is the group's first character and none otherwise. `isSpace` says its first scalar is
// white space, so it hangs at a line's end. `tracking` is the space added after it at the run's static tracking, in
// output pixels, and `widestTracking` at the widest tracking the run takes, both 0 for a character with no glyph of
// its own.
struct StyledCharacter: Equatable, Sendable {
    // MARK: - Property
    let character: Character
    let range: Range<Int>
    let source: Int
    let style: CharacterStyle
    let runFace: FontFace
    let glyphs: [StyledGlyph]
    let isSpace: Bool
    let tracking: Double
    let widestTracking: Double

    var advance: Double {
        glyphs.map(\.glyph.advance).reduce(0, +)
    }

    // MARK: - Initializer
    init(
        character: Character,
        range: Range<Int>,
        source: Int,
        style: CharacterStyle,
        runFace: FontFace,
        glyphs: [StyledGlyph],
        isSpace: Bool,
        tracking: Double,
        widestTracking: Double
    ) {
        self.character = character
        self.range = range
        self.source = source
        self.style = style
        self.runFace = runFace
        self.glyphs = glyphs
        self.isSpace = isSpace
        self.tracking = tracking
        self.widestTracking = widestTracking
    }

    // MARK: - Public
    // MARK: - Private
}
