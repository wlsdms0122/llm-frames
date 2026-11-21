//
//  Reveal.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How much of a receiver of `reveal` shows, from 0 (nothing) to 1 (everything). An eased value past either end is held
// at it.
struct Reveal: Equatable, Sendable {
    // MARK: - Property
    static let full = Reveal(amount: 1)

    let amount: Double

    // MARK: - Initializer
    init(amount: Double) {
        self.amount = min(max(amount, 0), 1)
    }

    // MARK: - Public
    // The part of the rectangle a wipe from the edge has shown, the whole of it at 1.
    func rectangle(
        wiping rectangle: Rectangle,
        from edge: RevealEdge
    ) -> Rectangle {
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

    // MARK: - Private
}
