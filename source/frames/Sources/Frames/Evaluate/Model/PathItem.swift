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

    // The outline carried by `transform` into output pixels and the part of it the stroke draws there. Trim fractions
    // are of the item's own outline, and the stroke's width, caps, joins and arrowheads are laid on the carried one.
    // Nil without a stroke, for an outline of no length, and where the transform flattens the plane.
    package func carriedStroke(by transform: AffineTransform) -> (outline: PathOutline, drawn: DrawnStroke)? {
        let outline = PathOutline(geometry)
        guard let stroke, transform.inverse != nil, outline.length > 0 else { return nil }

        let carried = outline.carried(by: transform)
        let fraction = { (end: Double) in
            outline.distance(min(max(end, 0), 1) * outline.length, onto: carried) / carried.length
        }
        let drawn = DrawnStroke(
            stroke: stroke,
            trim: Trim(start: fraction(trim.start), end: fraction(trim.end)),
            isClosed: isClosed
        )

        return (carried, drawn)
    }

    // The convex parts of what the stroke draws past its outline grown by half its width, each by its corners in
    // order, in the item's own coordinates: its arrowheads, the points of its miter joins and the ends of its square
    // caps (`PathOutline.overhangs`), laid in output pixels on the outline `transform` carries.
    package func overhangs(carriedBy transform: AffineTransform) -> [[Point]] {
        guard let stroke, case let (outline, drawn)? = carriedStroke(by: transform), let back = transform.inverse else {
            return []
        }

        return outline.overhangs(of: stroke, drawn: drawn).map { corners in corners.map(back.apply(to:)) }
    }

    // The axis-aligned box of what the item draws without its shadow, after `transform`, its stroke drawn in output
    // pixels on the outline `item` carries: its outline grown by half its stroke width, united with its overhangs. The
    // outline lies within the hull of its rectangle's corners or its points, and the stroke within a disc half its
    // width about every point of the carried outline.
    package func drawnBounds(
        carriedBy item: AffineTransform,
        under transform: AffineTransform = .identity
    ) -> Rectangle {
        let hull = switch geometry {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            transform.apply(toCornersOf: rectangle)

        case let .polyline(points, _):
            points.map(transform.apply(to:))
        }
        // The disc is carried back by the item's inverse and on by `transform`, onto an ellipse reaching this far each
        // way along each axis.
        let half = item.inverse == nil ? 0 : (stroke?.width ?? 0) / 2
        let disc = item.inverse.map { $0.concatenating(transform) } ?? transform
        let across = half * (disc.a * disc.a + disc.c * disc.c).squareRoot()
        let down = half * (disc.b * disc.b + disc.d * disc.d).squareRoot()
        let outline = Rectangle(bounding: hull)
        let stroked = Rectangle(
            x: outline.x - across,
            y: outline.y - down,
            width: outline.width + 2 * across,
            height: outline.height + 2 * down
        )
        let overhangs = overhangs(carriedBy: item).flatMap { $0 }.map(transform.apply(to:))

        return overhangs.isEmpty ? stroked : stroked.union(Rectangle(bounding: overhangs))
    }

    // MARK: - Private
}
