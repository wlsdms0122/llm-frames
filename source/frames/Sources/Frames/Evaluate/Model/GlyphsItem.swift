//
//  GlyphsItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Shaped glyphs and their background in the text's own box of `size`. `layer` is nil for an item that draws every step,
// or the one step a unit's item draws.
package struct GlyphsItem: Equatable, Sendable {
    // MARK: - Property
    package let size: Size
    package let runs: [DrawnGlyphRun]
    package let layer: GlyphLayer?
    package let background: GlyphBackground?

    // MARK: - Initializer
    package init(
        size: Size,
        runs: [DrawnGlyphRun],
        layer: GlyphLayer? = nil,
        background: GlyphBackground?
    ) {
        self.size = size
        self.runs = runs
        self.layer = layer
        self.background = background
    }

    // Shaped text at `time` in its box then, whose top left is `text.box(at: time)`'s origin in the box at the static
    // values. Its background fills that whole box with its radius and colour then.
    init(
        text: ResolvedText,
        at time: Double
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
    // `parts` name, with no background. A run the unit has neither glyphs nor parts of is left out.
    init(
        carrying glyphs: [GlyphRange],
        parts: [UnitPart],
        of item: GlyphsItem,
        layer: GlyphLayer
    ) {
        self.init(
            size: item.size,
            runs: item.runs.indices.compactMap { index in
                let ranges = glyphs.filter { $0.run == index }
                let carried = parts.filter { $0.run == index }
                guard !ranges.isEmpty || !carried.isEmpty else { return nil }

                return item.runs[index].carrying(glyphs: ranges, parts: carried)
            },
            layer: layer,
            background: nil
        )
    }

    // MARK: - Public
    // The box and every highlight and underline rectangle, each cut to its band where there are bands, a rectangle
    // outside its band left out: what the item covers without its strokes.
    package func filledRects() -> [Rectangle] {
        let pieces = runs.flatMap { run in
            cut(run.highlight?.rects ?? [], to: run.highlight?.bands)
                + cut(run.underline?.rects ?? [], to: run.underline?.bands)
        }

        return [Rectangle(x: 0, y: 0, width: size.width, height: size.height)] + pieces
    }

    // The filled rectangles with the box grown by half the widest stroke, since a stroke is centred on outlines that
    // reach the box's edges.
    package func drawnBounds() -> Rectangle {
        let half = (runs.compactMap(\.stroke).map(\.width).max() ?? 0) / 2
        let stroked = Rectangle(x: 0, y: 0, width: size.width, height: size.height).grown(by: half)

        return filledRects().reduce(stroked) { $0.union($1) }
    }

    // MARK: - Private
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
