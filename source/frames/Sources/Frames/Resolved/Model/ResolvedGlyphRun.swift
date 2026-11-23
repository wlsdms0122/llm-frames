//
//  ResolvedGlyphRun.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A run of shaped glyphs in one face and size, set from the text's run at `source`, each glyph at its pen position in
// its text's own box with the baseline shift not applied, and its placement offset from the pen, narrowed about its
// origin along its own horizontal axis by `horizontalScale` and then turned 90 degrees clockwise about it where
// `isSideways`. `color` and `baselineShift` are keyframe lists and `stroke` is off or a timed `{width, color}`.
// `staticTracking` is the tracking resolve set after each of its characters with glyphs of their own but a line's last,
// and `tracking` is off or a keyframe list of the tracking added after each of them beyond it, both in output pixels.
struct ResolvedGlyphRun: Equatable, Sendable {
    // MARK: - Property
    let source: Int
    let font: PinnedFile
    let face: String
    let size: Double
    let color: TimedValue
    let stroke: TimedValue
    let baselineShift: TimedValue
    let isSideways: Bool
    let horizontalScale: Double
    let staticTracking: Double
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
        isSideways: Bool,
        horizontalScale: Double,
        staticTracking: Double,
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
        self.isSideways = isSideways
        self.horizontalScale = horizontalScale
        self.staticTracking = staticTracking
        self.tracking = tracking
        self.highlight = highlight
        self.underline = underline
        self.glyphs = glyphs
    }

    // MARK: - Public
    // MARK: - Private
}
