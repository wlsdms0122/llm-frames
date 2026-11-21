//
//  GlyphsItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Shaped glyphs and their background in a title's text box at one instant, of `size`, origin at its top left. `layer`
// is nil for an item that draws every step, or the one step a unit's item draws. `unit` is the index among its title's
// units in reading order of a unit's item's unit, and nil for any other item. `unitBox` is a unit's box for a unit's
// item, which holds its stroke and its parts, and nil for any other. `extent` is the drawn extent of its glyphs, its
// unit's for a unit's item and its title's for any other, which is the text box when it is not given. The background's
// rect is the text box grown by the background's padding.
package struct GlyphsItem: Equatable, Sendable {
    // MARK: - Property
    package let size: Size
    package let runs: [DrawnGlyphRun]
    package let layer: GlyphLayer?
    package let unit: Int?
    package let unitBox: Rectangle?
    package let extent: Rectangle
    package let background: GlyphBackground?

    // MARK: - Initializer
    package init(
        size: Size,
        runs: [DrawnGlyphRun],
        layer: GlyphLayer? = nil,
        unit: Int? = nil,
        unitBox: Rectangle? = nil,
        extent: Rectangle? = nil,
        background: GlyphBackground?
    ) {
        self.size = size
        self.runs = runs
        self.layer = layer
        self.unit = unit
        self.unitBox = unitBox
        self.extent = extent ?? Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        self.background = background
    }

    // Shaped text at `time` in its text box then, whose top left is `text.textBox(at: time)`'s origin in the box at the
    // static values, with its drawn extent then. Its background fills the title's box then, the text box grown by the
    // padding then, with its radius and colour then. `factor` is the title's scale factor then, which every run's stroke
    // width is written at in output pixels.
    init(
        text: ResolvedText,
        factor: Double,
        at time: SampleTime
    ) {
        let textBox = text.textBox(at: time)
        let box = text.box(at: time)
        let moves = text.glyphMoves(at: time)
        let pieceMoves = text.pieceMoves(of: moves)
        let placed = { (move: Point) in Point(x: move.x - textBox.x, y: move.y - textBox.y) }

        self.init(
            size: Size(width: textBox.width, height: textBox.height),
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
            extent: text.extent(at: time),
            background: text.background.flatMap { background in
                background.color.sampled(at: time, as: .leaf(.color)).color.map { color in
                    GlyphBackground(
                        rectangle: Rectangle(
                            x: box.x - textBox.x,
                            y: box.y - textBox.y,
                            width: box.width,
                            height: box.height
                        ),
                        radius: background.radius.sampled(at: time, as: .leaf(.length(.any))).number ?? 0,
                        color: color
                    )
                }
            }
        )
    }

    // The item of `layer` of the unit at `unit` from the whole title's `item`: the unit's `glyphs` in their runs and the
    // pieces its `parts` name, in its `box`, with its drawn `extent`, with no background, its strokes widened by
    // `factor`, the scale factor of the unit's motion. A run the unit has neither glyphs nor parts of is left out.
    init(
        unit: Int,
        carrying glyphs: [GlyphRange],
        parts: [UnitPart],
        in box: Rectangle,
        extent: Rectangle,
        of item: GlyphsItem,
        layer: GlyphLayer,
        factor: Double
    ) {
        self.init(
            size: item.size,
            runs: Set(glyphs.map(\.run) + parts.map(\.run)).sorted().map { index in
                item.runs[index].carrying(
                    glyphs: glyphs.filter { $0.run == index },
                    parts: parts.filter { $0.run == index },
                    factor: factor
                )
            },
            layer: layer,
            unit: unit,
            unitBox: box,
            extent: extent,
            background: nil
        )
    }

    // MARK: - Public
    package var textBox: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // A whole title's box, its background's rect or its text box without one, and every highlight and underline
    // rectangle: what it covers without its strokes.
    package func filledRects() -> [Rectangle] {
        [background?.rectangle ?? textBox] + pieces()
    }

    // What the item draws, which a reveal wipes across: its extent grown by half the widest stroke, since a stroke is
    // centred on outlines that reach the extent's edges, and joined with its background's rect and every highlight and
    // underline rectangle, each cut to its band where there are bands, a rectangle outside its band left out. A stroke
    // is drawn in output pixels on the outlines `transform` carries, so the disc it sweeps is carried back by the
    // transform's inverse, and is nothing where the transform flattens the plane.
    package func drawnBounds(carriedBy transform: AffineTransform) -> Rectangle {
        let half = (runs.compactMap(\.stroke).map(\.width).max() ?? 0) / 2
        let reach = transform.inverse?.reach(ofDisc: half) ?? Size(width: 0, height: 0)
        let stroked = Rectangle(
            x: extent.x - reach.width,
            y: extent.y - reach.height,
            width: extent.width + 2 * reach.width,
            height: extent.height + 2 * reach.height
        )
        let drawn = pieces().reduce(stroked) { $0.union($1) }

        return background.map { drawn.union($0.rectangle) } ?? drawn
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
