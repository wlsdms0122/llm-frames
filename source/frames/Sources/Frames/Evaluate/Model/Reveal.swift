//
//  Reveal.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How much of a receiver of `reveal` shows, from 0 (nothing) to 1 (everything), and the side a wipe starts from. An
// eased value past either end is held at it, since nothing shows less than nothing or more than everything.
struct Reveal: Equatable, Sendable {
    // MARK: - Property
    static let full = Reveal(amount: 1, edge: .left)

    let amount: Double
    let edge: RevealEdge

    // MARK: - Initializer
    init(
        amount: Double,
        edge: RevealEdge
    ) {
        self.amount = min(max(amount, 0), 1)
        self.edge = edge
    }

    // MARK: - Public
    // The part of the rectangle a wipe from the edge has shown, nil when it shows all of it.
    func rectangle(wiping rectangle: Rectangle) -> Rectangle? {
        guard amount < 1 else { return nil }

        let width = rectangle.width * amount
        let height = rectangle.height * amount

        switch edge {
        case .left:
            return Rectangle(x: rectangle.x, y: rectangle.y, width: width, height: rectangle.height)

        case .right:
            return Rectangle(
                x: rectangle.x + rectangle.width - width,
                y: rectangle.y,
                width: width,
                height: rectangle.height
            )

        case .top:
            return Rectangle(x: rectangle.x, y: rectangle.y, width: rectangle.width, height: height)

        case .bottom:
            return Rectangle(
                x: rectangle.x,
                y: rectangle.y + rectangle.height - height,
                width: rectangle.width,
                height: height
            )
        }
    }

    // A dim's hole, closing in from all the dim darkens (`room`, nothing darkened) to the area it leaves lit.
    func hole(
        closingFrom room: Rectangle,
        to area: Rectangle
    ) -> Rectangle {
        .interpolate(from: room, to: area, progress: amount)
    }

    // An arrow's head as it grows from its tail.
    func head(
        growingFrom tail: Point,
        to head: Point
    ) -> Point {
        .interpolate(from: tail, to: head, progress: amount)
    }

    // MARK: - Private
}
