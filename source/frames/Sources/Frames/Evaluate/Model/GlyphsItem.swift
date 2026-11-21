//
//  GlyphsItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Shaped glyphs and their background in the text's own box of `size`. `layer` is nil for an item that draws every step,
// or the one step a unit's item draws. `unitBox` is a unit's box in the text's box for a unit's item, which holds its
// stroke and its parts, and `unitGlyphBox` the box its glyphs lie in, which a reveal wipes across; both are nil for an
// item whose glyphs fill the text's box.
package struct GlyphsItem: Equatable, Sendable {
    // MARK: - Property
    package let size: Size
    package let runs: [DrawnGlyphRun]
    package let layer: GlyphLayer?
    package let unitBox: Rectangle?
    package let unitGlyphBox: Rectangle?
    package let background: GlyphBackground?

    // MARK: - Initializer
    package init(
        size: Size,
        runs: [DrawnGlyphRun],
        layer: GlyphLayer? = nil,
        unitBox: Rectangle? = nil,
        unitGlyphBox: Rectangle? = nil,
        background: GlyphBackground?
    ) {
        self.size = size
        self.runs = runs
        self.layer = layer
        self.unitBox = unitBox
        self.unitGlyphBox = unitGlyphBox
        self.background = background
    }

    // Shaped text at `time` in its box then, whose top left is `text.box(at: time)`'s origin in the box at the static
    // values. Its background fills that whole box with its radius and colour then. `factor` is the title's scale factor
    // then, which every run's stroke width is written at in output pixels.
    init(
        text: ResolvedText,
        factor: Double,
        at time: SampleTime
    ) {
        let box = text.box(at: time)
        let moves = text.glyphMoves(at: time)
        let pieceMoves = text.pieceMoves(of: moves)
        let placed = { (move: Point) in Point(x: move.x - box.x, y: move.y - box.y) }

        self.init(
            size: Size(width: box.width, height: box.height),
            runs: text.runs.indices.map { index in
                DrawnGlyphRun(
                    run: text.runs[index],
                    factor: factor,
                    at: time,
                    moves: moves[index].map(placed),
                    pieceMove: PieceMove(
                        start: placed(pieceMoves[index].start),
                        end: placed(pieceMoves[index].end)
                    )
                )
            },
            background: text.background.flatMap { background in
                background.color.sampled(at: time, as: .leaf(.color)).color.map { color in
                    GlyphBackground(
                        rectangle: Rectangle(x: 0, y: 0, width: box.width, height: box.height),
                        radius: background.radius.sampled(at: time, as: .leaf(.length(.any))).number ?? 0,
                        color: color
                    )
                }
            }
        )
    }

    // A unit's item of `layer` from the whole title's `item`: the unit's `glyphs` in their runs and the pieces its
    // `parts` name, in its `box`, its glyphs lying in `glyphBox`, with no background, its strokes widened by `factor`,
    // the scale factor of the unit's motion. A run the unit has neither glyphs nor parts of is left out.
    init(
        carrying glyphs: [GlyphRange],
        parts: [UnitPart],
        in box: Rectangle,
        glyphBox: Rectangle,
        of item: GlyphsItem,
        layer: GlyphLayer,
        factor: Double
    ) {
        self.init(
            size: item.size,
            runs: item.runs.indices.compactMap { index in
                let ranges = glyphs.filter { $0.run == index }
                let carried = parts.filter { $0.run == index }
                guard !ranges.isEmpty || !carried.isEmpty else { return nil }

                return item.runs[index].carrying(glyphs: ranges, parts: carried, factor: factor)
            },
            layer: layer,
            unitBox: box,
            unitGlyphBox: glyphBox,
            background: nil
        )
    }

    // MARK: - Public
    package var textBox: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // A whole title's text box and every highlight and underline rectangle: what it covers without its strokes.
    package func filledRects() -> [Rectangle] {
        [textBox] + pieces()
    }

    // What the item draws, which a reveal wipes across: the box its glyphs lie in, a unit's glyph box or a whole
    // title's text box, grown by half the widest stroke, since a stroke is centred on outlines that reach the box's
    // edges, and joined with every highlight and underline rectangle, each cut to its band where there are bands, a
    // rectangle outside its band left out. A stroke is drawn in output pixels on the outlines `transform` carries, so
    // the disc it sweeps is carried back by the transform's inverse, and is nothing where the transform flattens the
    // plane.
    package func drawnBounds(carriedBy transform: AffineTransform) -> Rectangle {
        let glyphBox = unitGlyphBox ?? textBox
        let half = (runs.compactMap(\.stroke).map(\.width).max() ?? 0) / 2
        let reach = transform.inverse?.reach(ofDisc: half) ?? Size(width: 0, height: 0)
        let stroked = Rectangle(
            x: glyphBox.x - reach.width,
            y: glyphBox.y - reach.height,
            width: glyphBox.width + 2 * reach.width,
            height: glyphBox.height + 2 * reach.height
        )

        return pieces().reduce(stroked) { $0.union($1) }
    }

    // MARK: - Private
    private func pieces() -> [Rectangle] {
        runs.flatMap { run in
            cut(run.highlight?.rects ?? [], to: run.highlight?.bands)
                + cut(run.underline?.rects ?? [], to: run.underline?.bands)
        }
    }

    private func cut(
        _ rects: [Rectangle],
        to bands: [ClosedRange<Double>]?
    ) -> [Rectangle] {
        guard let bands else { return rects }

        return zip(rects, bands).compactMap { rect, band in
            let start = max(rect.x, band.lowerBound)
            let end = min(rect.x + rect.width, band.upperBound)
            guard start < end else { return nil }

            return Rectangle(x: start, y: rect.y, width: end - start, height: rect.height)
        }
    }
}
