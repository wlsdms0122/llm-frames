//
//  PathItem.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A rectangle, an ellipse or a polyline, filled and stroked: `fill` paints its inside, `stroke` draws the part of its
// outline `trim` leaves, and `shadow` is cast below both.
package struct PathItem: Equatable, Sendable {
    // MARK: - Property
    package let geometry: PathGeometry
    package let fill: Color?
    package let stroke: PathStroke?
    package let trim: Trim
    package let shadow: DropShadow?

    // MARK: - Initializer
    package init(
        geometry: PathGeometry,
        fill: Color?,
        stroke: PathStroke?,
        trim: Trim = .whole,
        shadow: DropShadow? = nil
    ) {
        self.geometry = geometry
        self.fill = fill
        self.stroke = stroke
        self.trim = trim
        self.shadow = shadow
    }

    // A square-cornered rectangle filled with a colour, as a solid or a colour cover draws.
    package init(
        filling rectangle: Rectangle,
        color: Color
    ) {
        self.init(geometry: .rect(rectangle, radius: 0), fill: color, stroke: nil)
    }

    // MARK: - Public
    package var isClosed: Bool {
        switch geometry {
        case .rect, .ellipse:
            true

        case let .polyline(_, isClosed):
            isClosed
        }
    }

    package var drawnStroke: DrawnStroke? {
        stroke.map { stroke in DrawnStroke(stroke: stroke, trim: trim, isClosed: isClosed) }
    }

    // The convex parts of what the stroke draws past its outline grown by half its width, each by its corners in
    // order: its arrowheads, the points of its miter joins and the ends of its square caps (`PathOutline.overhangs`).
    package var overhangs: [[Point]] {
        guard let stroke, let drawn = drawnStroke else { return [] }

        return PathOutline(geometry).overhangs(of: stroke, drawn: drawn)
    }

    // The axis-aligned box of what the item draws without its shadow, after `transform`: its outline grown by half its
    // stroke width, united with its overhangs. The outline lies within the hull of its rectangle's corners or its
    // points, and the stroke within a disc half its width about every point of it.
    package func drawnBounds(under transform: AffineTransform = .identity) -> Rectangle {
        let hull = switch geometry {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            transform.apply(toCornersOf: rectangle)

        case let .polyline(points, _):
            points.map(transform.apply(to:))
        }
        let half = (stroke?.width ?? 0) / 2
        // A disc of that radius is carried onto an ellipse reaching this far each way along each axis.
        let across = half * (transform.a * transform.a + transform.c * transform.c).squareRoot()
        let down = half * (transform.b * transform.b + transform.d * transform.d).squareRoot()
        let outline = Rectangle(bounding: hull)
        let stroked = Rectangle(
            x: outline.x - across,
            y: outline.y - down,
            width: outline.width + 2 * across,
            height: outline.height + 2 * down
        )
        let overhangs = overhangs.flatMap { $0 }.map(transform.apply(to:))

        return overhangs.isEmpty ? stroked : stroked.union(Rectangle(bounding: overhangs))
    }

    // MARK: - Private
}
