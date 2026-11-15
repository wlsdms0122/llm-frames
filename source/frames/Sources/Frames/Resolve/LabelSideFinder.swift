//
//  LabelSideFinder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The side rule of a shape's label wherever the shape is drawn: the first of the theme's sides on which the label,
// outside the shape's box, its background touching that side and centred along it, fits inside the room it is
// measured against. For an arrow the box is the one it fills from tail to head.
struct LabelSideFinder: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func side(
        of size: Size,
        beside box: Rectangle,
        in room: Rectangle,
        sides: [Side]
    ) -> Side? {
        sides.first { room.contains(rectangle(of: size, beside: box, on: $0)) }
    }

    func rectangle(
        of size: Size,
        beside box: Rectangle,
        on side: Side
    ) -> Rectangle {
        switch side {
        case .left:
            Rectangle(x: box.x - size.width, y: box.center.y - size.height / 2, width: size.width, height: size.height)

        case .right:
            Rectangle(x: box.maxX, y: box.center.y - size.height / 2, width: size.width, height: size.height)

        case .top:
            Rectangle(x: box.center.x - size.width / 2, y: box.y - size.height, width: size.width, height: size.height)

        case .bottom:
            Rectangle(x: box.center.x - size.width / 2, y: box.maxY, width: size.width, height: size.height)
        }
    }

    // The tip sits at the middle of the area's side, and the box is as wide as the head or the line, whichever is
    // wider.
    func arrowBox(
        pointingAt area: Rectangle,
        from side: Side,
        length: Double,
        breadth: Double
    ) -> Rectangle {
        switch side {
        case .left:
            Rectangle(x: area.x - length, y: area.center.y - breadth / 2, width: length, height: breadth)

        case .right:
            Rectangle(x: area.maxX, y: area.center.y - breadth / 2, width: length, height: breadth)

        case .top:
            Rectangle(x: area.center.x - breadth / 2, y: area.y - length, width: breadth, height: length)

        case .bottom:
            Rectangle(x: area.center.x - breadth / 2, y: area.maxY, width: breadth, height: length)
        }
    }

    // MARK: - Private
}
