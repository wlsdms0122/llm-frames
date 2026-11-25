//
//  PathItem.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A rectangle, an ellipse or a path of cubic Bézier segments, filled and stroked: `fill` paints its inside, `stroke`
// draws the part of its outline `trim` leaves, and `shadow` is cast below both.
package struct PathItem: Equatable, Sendable {
    // MARK: - Property
    package let geometry: PathGeometry
    package let fill: Paint?
    package let stroke: PathStroke?
    package let trim: Trim
    package let shadow: DropShadow?

    // MARK: - Initializer
    package init(
        geometry: PathGeometry,
        fill: Paint?,
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
        self.init(geometry: .rect(rectangle, radius: 0), fill: .color(color), stroke: nil)
    }

    // MARK: - Public
    package var isClosed: Bool {
        switch geometry {
        case .rect, .ellipse:
            true

        case let .path(_, isClosed):
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

    // The convex parts of what the stroke's line draws past its outline grown by its reach, each by its corners in
    // order, in the item's own coordinates: the points of the miter joins and the ends of the square caps of the
    // centred stroke it is cut from (`PathOutline.overhangs`), laid in output pixels on the outline `transform` carries.
    // An inside stroke has none, since it lies inside its outline. Its heads are `heads(carriedBy:)`.
    package func overhangs(carriedBy transform: AffineTransform) -> [[Point]] {
        guard case let (stroke, outline, drawn, back)? = overhanging(carriedBy: transform) else { return [] }

        return outline.overhangs(of: stroke.traced, drawn: drawn).map { corners in corners.map(back.apply(to:)) }
    }

    // The outline of each head the stroke draws, a closed path filled by the nonzero rule, in the item's own
    // coordinates, laid in output pixels on the outline `transform` carries.
    package func heads(carriedBy transform: AffineTransform) -> [PathGeometry] {
        guard case let (outline, drawn)? = carriedStroke(by: transform), let back = transform.inverse else { return [] }

        return outline.arrowheads(of: drawn).map { head in head.geometry(carriedBy: back) }
    }

    // The axis-aligned box of what the item draws without its shadow, after `transform`, its stroke drawn in output
    // pixels on the outline `item` carries: its outline grown by the stroke's reach past it, united with its overhangs
    // and the tight box of each head's outline, the curve's box as a path's (FRAMES-11 Shapes). The outline lies
    // within the box of its geometry, and the stroke within a disc about every point of the carried outline, its
    // radius half the stroke's width for a centred stroke, its width for an outside one and 0 for an inside one, which
    // lies inside the outline.
    package func drawnBounds(
        carriedBy item: AffineTransform,
        under transform: AffineTransform = .identity
    ) -> Rectangle {
        // A disc in output pixels is carried back by the item's inverse and on by `transform`, onto an ellipse reaching
        // this far each way along each axis.
        let radius = item.inverse == nil ? 0 : stroke.map { $0.width * $0.align.reach } ?? 0
        let disc = item.inverse.map { $0.concatenating(transform) } ?? transform
        let reach = disc.reach(ofDisc: radius)
        let outline = geometry.bounds(carriedBy: transform)
        let stroked = Rectangle(
            x: outline.x - reach.width,
            y: outline.y - reach.height,
            width: outline.width + 2 * reach.width,
            height: outline.height + 2 * reach.height
        )
        guard case let (stroke, carried, drawn, back)? = overhanging(carriedBy: item) else { return stroked }

        let corners = carried.overhangs(of: stroke.traced, drawn: drawn).flatMap { $0 }
            .map { transform.apply(to: back.apply(to: $0)) }
        let heads = carried.arrowheads(of: drawn).map { head in head.geometry().bounds(carriedBy: disc) }

        return ([corners.isEmpty ? nil : Rectangle(bounding: corners)].compactMap { $0 } + heads)
            .reduce(stroked) { bounds, part in bounds.union(part) }
    }

    // MARK: - Private
    // The stroke, the outline `transform` carries, the part of it the stroke draws and the inverse of `transform`,
    // where the stroke draws past its outline: nil for an inside stroke and where `carriedStroke(by:)` gives nothing.
    private func overhanging(
        carriedBy transform: AffineTransform
    ) -> (stroke: PathStroke, outline: PathOutline, drawn: DrawnStroke, back: AffineTransform)? {
        guard
            let stroke,
            stroke.align != .inside,
            case let (outline, drawn)? = carriedStroke(by: transform),
            let back = transform.inverse
        else { return nil }

        return (stroke, outline, drawn, back)
    }
}
