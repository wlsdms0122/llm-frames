//
//  ResolvedGlyphRun.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A run of shaped glyphs in one face and size, set from the text's run at `source`, each glyph's origin in its text's
// own box with the baseline shift not applied. `color` and `baselineShift` are keyframe lists, `stroke` is off or a
// timed `{width, color}`, and `tracking` is off or a keyframe list of the tracking added after each grapheme cluster
// beyond the static tracking, in output pixels.
struct ResolvedGlyphRun: Equatable, Sendable {
    // MARK: - Property
    let source: Int
    let font: PinnedFile
    let face: String
    let size: Double
    let color: TimedValue
    let stroke: TimedValue
    let baselineShift: TimedValue
    let tracking: TimedValue
    let highlight: ResolvedHighlight?
    let underline: ResolvedUnderline?
    let glyphs: [PositionedGlyph]

    // MARK: - Initializer
    init(
        source: Int,
        font: PinnedFile,
        face: String,
        size: Double,
        color: TimedValue,
        stroke: TimedValue,
        baselineShift: TimedValue,
        tracking: TimedValue,
        highlight: ResolvedHighlight?,
        underline: ResolvedUnderline?,
        glyphs: [PositionedGlyph]
    ) {
        self.source = source
        self.font = font
        self.face = face
        self.size = size
        self.color = color
        self.stroke = stroke
        self.baselineShift = baselineShift
        self.tracking = tracking
        self.highlight = highlight
        self.underline = underline
        self.glyphs = glyphs
    }

    // MARK: - Public
    // MARK: - Private
}
