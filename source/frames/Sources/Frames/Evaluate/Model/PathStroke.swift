//
//  PathStroke.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A stroke centred on an outline, its `paint` colouring its arrowheads too. `dash` is nil for a whole stroke, or an
// even number of lengths, the dashes and gaps in turn, laid from the start of the stroke as drawn and moved back along
// it by `dashOffset`. The dash lengths are in the item's own coordinates, carried by its transform with the outline.
package struct PathStroke: Equatable, Sendable {
    // MARK: - Property
    package let width: Double
    package let paint: Paint
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
        join: StrokeJoin,
        cap: StrokeCap,
        start: StrokeEnd,
        end: StrokeEnd,
        dash: [Double]? = nil,
        dashOffset: Double = 0
    ) {
        self.width = width
        self.paint = paint
        self.join = join
        self.cap = cap
        self.start = start
        self.end = end
        self.dash = dash
        self.dashOffset = dashOffset
    }

    // MARK: - Public
    // MARK: - Private
}
