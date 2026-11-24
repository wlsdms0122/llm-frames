//
//  BoxPlacement.swift
//  Frames
//
//  Created by JSilver on 11/24/26.
//

// How a box placed by a placement name sits inside a frame: `name`, one of the nine placement names, `padding`, the
// theme `placement.padding`, and `edge`, the inset on the top or bottom edge, a text style's `offset` or the padding,
// both in output pixels at the sequence's length scale.
struct BoxPlacement: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let padding: Double
    let edge: Double

    // MARK: - Initializer
    init(
        name: String,
        padding: Double,
        edge: Double
    ) {
        self.name = name
        self.padding = padding
        self.edge = edge
    }

    // MARK: - Public
    // Where the anchor point goes of a box of `size` placed inside `frame`, inset by the padding on the edges the name
    // sits on, or by the edge on the top or bottom. A box in the middle of an axis is centred on the whole frame.
    func position(
        of size: Size,
        anchor: Point,
        in frame: Rectangle
    ) -> Point {
        let x = name.hasSuffix("left")
            ? padding
            : name.hasSuffix("right") ? frame.width - padding - size.width : (frame.width - size.width) / 2
        let y = name.hasPrefix("top")
            ? edge
            : name.hasPrefix("bottom") ? frame.height - edge - size.height : (frame.height - size.height) / 2

        return Point(x: frame.x + x + anchor.x, y: frame.y + y + anchor.y)
    }

    // MARK: - Private
}
