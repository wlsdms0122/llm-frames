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

    // Whether the stroke as drawn ends in an arrowhead at either end, which takes no length to know.
    package var hasArrowhead: Bool {
        drawnStroke(length: 1).map { $0.hasStartHead || $0.hasEndHead } ?? false
    }

    // The part of the outline the stroke draws along an outline `length` long, nil where it draws nothing.
    package func drawnStroke(length: Double) -> DrawnStroke? {
        stroke.flatMap { stroke in DrawnStroke(stroke: stroke, trim: trim, isClosed: isClosed, length: length) }
    }

    // MARK: - Private
}
