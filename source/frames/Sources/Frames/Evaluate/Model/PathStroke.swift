//
//  PathStroke.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A stroke along an outline, on the side of it `align` names, its `paint` colouring its arrowheads too. `dash` is nil for a whole stroke, or an
// even number of lengths, the dashes and gaps in turn, laid from the start of the stroke as drawn and moved back along
// it by `dashOffset`. The dash lengths are in the item's own coordinates, carried by its transform with the outline.
package struct PathStroke: Equatable, Sendable {
    // MARK: - Property
    package let width: Double
    package let paint: Paint
    package let align: StrokeAlign
    package let join: StrokeJoin
    package let cap: StrokeCap
    package let start: StrokeEnd
    package let end: StrokeEnd
    package let dash: [Double]?
    package let dashOffset: Double

    // MARK: - Initializer
    package init(
        width: Double,
        paint: Paint,
        align: StrokeAlign = .center,
        join: StrokeJoin,
        cap: StrokeCap,
        start: StrokeEnd,
        end: StrokeEnd,
        dash: [Double]? = nil,
        dashOffset: Double = 0
    ) {
        self.width = width
        self.paint = paint
        self.align = align
        self.join = join
        self.cap = cap
        self.start = start
        self.end = end
        self.dash = dash
        self.dashOffset = dashOffset
    }

    // MARK: - Public
    // The centred stroke this one is cut from: itself when it is centred, and otherwise the centred stroke of twice its
    // width, whose joins, caps and dashes it keeps where the cut leaves them.
    package var traced: PathStroke {
        guard align != .center else { return self }

        return PathStroke(
            width: align.tracedWidth(of: width),
            paint: paint,
            join: join,
            cap: cap,
            start: start,
            end: end,
            dash: dash,
            dashOffset: dashOffset
        )
    }

    // MARK: - Private
}
