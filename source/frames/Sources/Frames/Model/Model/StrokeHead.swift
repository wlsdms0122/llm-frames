//
//  StrokeHead.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A head preset's values (FRAMES-11 Heads), in units of its stroke's width times its scale: `outline`, a closed path
// with its tip at the origin and its axis along the x axis from its base at x = -`length` to its tip, y across it to
// the right of the direction it points, and `inset`, how far back from the tip the stroke's line stops.
package struct StrokeHead: Equatable, Sendable {
    // MARK: - Property
    package let outline: [PathVertex<Point, Point>]
    package let length: Double
    package let inset: Double

    // Why frames refuses the head, nil where it keeps every rule: at least two vertices, a `length` above 0, an `inset`
    // from 0 to `length`, and nothing of the outline, its control points included, past the tip.
    package var refusal: String? {
        guard outline.count >= 2 else {
            return "a head's outline runs through at least two vertices, found \(outline.count)"
        }
        guard length > 0, length.isFinite else {
            return "a head's length is above 0, found \(JSONValue.number(length).written)"
        }
        guard inset >= 0, inset <= length else {
            return "a head's inset is from 0 to its length \(JSONValue.number(length).written), "
                + "found \(JSONValue.number(inset).written)"
        }
        guard controlPoints.allSatisfy({ $0.x <= 0 && $0.x.isFinite && $0.y.isFinite }) else {
            return "nothing of a head lies past its tip at x = 0, its control points included"
        }

        return nil
    }

    // Every vertex of the outline and every control point of its segments, which hold the curve it draws.
    package var controlPoints: [Point] {
        outline.flatMap { vertex in
            [
                vertex.vertex,
                Point(x: vertex.vertex.x + vertex.inTangent.x, y: vertex.vertex.y + vertex.inTangent.y),
                Point(x: vertex.vertex.x + vertex.outTangent.x, y: vertex.vertex.y + vertex.outTangent.y)
            ]
        }
    }

    // MARK: - Initializer
    package init(
        outline: [PathVertex<Point, Point>],
        length: Double,
        inset: Double
    ) {
        self.outline = outline
        self.length = length
        self.inset = inset
    }

    // MARK: - Public
    // MARK: - Private
}
