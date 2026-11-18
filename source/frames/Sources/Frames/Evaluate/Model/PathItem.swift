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
    // A rect's and an ellipse's outline is closed, and a polyline's when it says so.
    package var isClosed: Bool {
        switch geometry {
        case .rect, .ellipse:
            true

        case let .polyline(_, isClosed):
            isClosed
        }
    }

    // The part of the outline the stroke draws and its arrowheads, nil without a stroke.
    package var drawnStroke: DrawnStroke? {
        stroke.map { stroke in DrawnStroke(stroke: stroke, trim: trim, isClosed: isClosed) }
    }

    // The stroke's arrowheads where they lie on the outline, the start's first.
    package var arrowheads: [Arrowhead] {
        drawnStroke.map { drawn in PathOutline(geometry).arrowheads(of: drawn) } ?? []
    }

    // The box of what the item draws without its shadow, in its own coordinates: its outline's box grown by half its
    // stroke width, united with the box of its arrowheads.
    package var drawnBounds: Rectangle {
        let outline = switch geometry {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            rectangle

        case let .polyline(points, _):
            Rectangle(bounding: points)
        }
        let stroked = outline.grown(by: (stroke?.width ?? 0) / 2)
        let heads = arrowheads.flatMap(\.corners)

        return heads.isEmpty ? stroked : stroked.union(Rectangle(bounding: heads))
    }

    // MARK: - Private
}
