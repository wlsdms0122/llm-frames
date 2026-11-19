//
//  DrawnGlyphRun.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A run of shaped glyphs as a `glyphs` item draws it at one instant: one face, size, colour and stroke, its highlight
// and underline, and each glyph's origin in the item's own box.
package struct DrawnGlyphRun: Equatable, Sendable {
    // MARK: - Property
    package let font: PinnedFile
    package let face: String
    package let size: Double
    package let color: Color
    package let stroke: TextStroke?
    package let highlight: DrawnHighlight?
    package let underline: DrawnUnderline?
    package let glyphs: [PositionedGlyph]

    // MARK: - Initializer
    package init(
        font: PinnedFile,
        face: String,
        size: Double,
        color: Color,
        stroke: TextStroke?,
        highlight: DrawnHighlight?,
        underline: DrawnUnderline?,
        glyphs: [PositionedGlyph]
    ) {
        self.font = font
        self.face = face
        self.size = size
        self.color = color
        self.stroke = stroke
        self.highlight = highlight
        self.underline = underline
        self.glyphs = glyphs
    }

    // A resolved run at `time`, its glyphs and pieces raised by its baseline shift then, its glyphs moved by `moves`,
    // one for each glyph, and its pieces' ends by `pieceMove`. A highlight rectangle is its piece grown by the padding
    // then, and an underline rectangle a band across its piece the width then thick, its top edge the offset then
    // below the baseline. The stroke is its width then times `factor`.
    init(
        run: ResolvedGlyphRun,
        factor: Double,
        at time: Double,
        moves: [Point],
        pieceMove: PieceMove
    ) {
        let length = ValueStructure.leaf(.length(.any))
        let shift = run.baselineShift.sampled(at: time, as: length).number ?? 0
        let stroke = run.stroke.sampled(at: time, as: LookStructureTable.textStroke)
        let span = { (x: Double, width: Double) in
            (x: x + pieceMove.start.x, width: width + pieceMove.end.x - pieceMove.start.x)
        }
        let rise = pieceMove.start.y - shift

        self.init(
            font: run.font,
            face: run.face,
            size: run.size,
            color: run.color.sampled(at: time, as: .leaf(.color)).color ?? Color(written: "#000000"),
            stroke: stroke["width"]?.number.flatMap { width in
                stroke["color"]?.color.map { TextStroke(width: width * factor, color: $0) }
            },
            highlight: run.highlight.flatMap { highlight in
                let structure = ValueStructure.leaf(.lengths(count: 2, domain: .nonNegative))
                let padding = highlight.padding.sampled(at: time, as: structure).numbers ?? [0, 0]

                return highlight.color.sampled(at: time, as: .leaf(.color)).color.map { color in
                    DrawnHighlight(
                        rects: highlight.rects.map { piece in
                            let (x, width) = span(piece.x, piece.width)

                            return Rectangle(
                                x: x - padding[1],
                                y: piece.y + rise - padding[0],
                                width: width + padding[1] * 2,
                                height: piece.height + padding[0] * 2
                            )
                        },
                        radius: highlight.radius.sampled(at: time, as: length).number ?? 0,
                        color: color,
                        bands: nil
                    )
                }
            },
            underline: run.underline.flatMap { underline in
                let width = underline.width.sampled(at: time, as: length).number ?? 0
                let offset = underline.offset.sampled(at: time, as: length).number ?? 0

                return underline.color.sampled(at: time, as: .leaf(.color)).color.map { color in
                    DrawnUnderline(
                        rects: underline.rects.map { piece in
                            let (x, length) = span(piece.x, piece.width)

                            return Rectangle(x: x, y: piece.y + rise + offset, width: length, height: width)
                        },
                        color: color,
                        bands: nil
                    )
                }
            },
            glyphs: zip(run.glyphs, moves).map { glyph, move in
                PositionedGlyph(id: glyph.id, x: glyph.x + move.x, y: glyph.y + move.y - shift)
            }
        )
    }

    // MARK: - Public
    // The run as a unit's item holds it: the glyphs of `glyphs`, ranges of this run, and the highlight and underline
    // pieces `parts` name, each whole, with its band the part's span cut to the rectangle drawn, and its stroke
    // `factor` times as wide.
    func carrying(
        glyphs ranges: [GlyphRange],
        parts: [UnitPart],
        factor: Double
    ) -> DrawnGlyphRun {
        DrawnGlyphRun(
            font: font,
            face: face,
            size: size,
            color: color,
            stroke: stroke.map { TextStroke(width: $0.width * factor, color: $0.color) },
            highlight: highlight.flatMap { highlight in
                parts.isEmpty
                    ? nil
                    : DrawnHighlight(
                        rects: parts.map { highlight.rects[$0.piece] },
                        radius: highlight.radius,
                        color: highlight.color,
                        bands: parts.map { band(of: $0, across: highlight.rects[$0.piece]) }
                    )
            },
            underline: underline.flatMap { underline in
                parts.isEmpty
                    ? nil
                    : DrawnUnderline(
                        rects: parts.map { underline.rects[$0.piece] },
                        color: underline.color,
                        bands: parts.map { band(of: $0, across: underline.rects[$0.piece]) }
                    )
            },
            glyphs: ranges.flatMap { range in glyphs[range.first..<range.first + range.count] }
        )
    }

    // MARK: - Private
    private func band(
        of part: UnitPart,
        across rect: Rectangle
    ) -> ClosedRange<Double> {
        let start = min(max(part.span.lowerBound, rect.x), rect.maxX)

        return start...max(start, min(part.span.upperBound, rect.maxX))
    }
}
