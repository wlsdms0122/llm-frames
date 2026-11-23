//
//  StyledCharacter.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A grapheme cluster of a paragraph as shaped: its range of the title's text in Unicode scalars, its embedding level
// before the lines are broken, the bidirectional classes its scalars are read as, the run it is set in, its index among
// the text's runs, that run's character style and the style's own face, and the glyphs it owns, those of its group of
// glyphs when it is the group's first character and none otherwise, in the order they lie on the line. `hangs` says it
// hangs at a line's end: its first scalar is white space, and it is no character of a horizontal-in-vertical
// composition, whose spaces are set in it. `tracking` is the space between it and a neighbour as placed that comes
// after it in the text, at the run's static tracking, in output pixels, and `widestTracking` at the widest tracking the
// run takes, both 0 for a character with no glyph of its own. `cursiveScripts` are the ISO 15924 codes of the cursive
// scripts it is a letter of.
struct StyledCharacter: Equatable, Sendable {
    // MARK: - Property
    let character: Character
    let range: Range<Int>
    let level: Int
    let bidiClasses: [BidiClass]
    let source: Int
    let style: CharacterStyle
    let runFace: FontFace
    let glyphs: [StyledGlyph]
    let hangs: Bool
    let tracking: Double
    let widestTracking: Double
    let cursiveScripts: [String]

    var advance: Double {
        glyphs.map(\.glyph.advance).reduce(0, +)
    }

    // MARK: - Initializer
    init(
        character: Character,
        range: Range<Int>,
        level: Int,
        bidiClasses: [BidiClass],
        source: Int,
        style: CharacterStyle,
        runFace: FontFace,
        glyphs: [StyledGlyph],
        hangs: Bool,
        tracking: Double,
        widestTracking: Double,
        cursiveScripts: [String]
    ) {
        self.character = character
        self.range = range
        self.level = level
        self.bidiClasses = bidiClasses
        self.source = source
        self.style = style
        self.runFace = runFace
        self.glyphs = glyphs
        self.hangs = hangs
        self.tracking = tracking
        self.widestTracking = widestTracking
        self.cursiveScripts = cursiveScripts
    }

    // MARK: - Public
    // MARK: - Private
}
