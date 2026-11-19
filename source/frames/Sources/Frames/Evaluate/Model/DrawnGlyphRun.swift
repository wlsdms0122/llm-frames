//
//  DrawnGlyphRun.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A run of shaped glyphs as a `glyphs` item draws it at one instant: one face, size, colour and stroke, each glyph's
// origin in the item's own box.
package struct DrawnGlyphRun: Equatable, Sendable {
    // MARK: - Property
    package let font: PinnedFile
    package let face: String
    package let size: Double
    package let color: Color
    package let stroke: TextStroke?
    package let glyphs: [PositionedGlyph]

    // MARK: - Initializer
    package init(
        font: PinnedFile,
        face: String,
        size: Double,
        color: Color,
        stroke: TextStroke?,
        glyphs: [PositionedGlyph]
    ) {
        self.font = font
        self.face = face
        self.size = size
        self.color = color
        self.stroke = stroke
        self.glyphs = glyphs
    }

    // A resolved run at `time`, its glyphs raised by its baseline shift then.
    init(
        run: ResolvedGlyphRun,
        at time: Double
    ) {
        let shift = run.baselineShift.sampled(at: time, as: .leaf(.length(.any))).number ?? 0
        let stroke = run.stroke.sampled(at: time, as: LookStructureTable.textStroke)

        self.init(
            font: run.font,
            face: run.face,
            size: run.size,
            color: run.color.sampled(at: time, as: .leaf(.color)).color ?? Color(written: "#000000"),
            stroke: stroke["width"]?.number.flatMap { width in
                stroke["color"]?.color.map { TextStroke(width: width, color: $0) }
            },
            glyphs: run.glyphs.map { glyph in PositionedGlyph(id: glyph.id, x: glyph.x, y: glyph.y - shift) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
