//
//  StrokeEndShape.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The head drawn at an end of a stroke, or none. A head is drawn in units of its stroke's width times its scale, its
// tip at the end of the stroke as drawn: `arrow` a filled triangle 4 long and 4 wide at its base, `line-arrow` the
// two sides of that triangle as bands 1 thick, `circle` a filled circle 4 across, `square` a filled square 4 on a side,
// `diamond` a filled rhombus 4 long and 4 wide, and `bar` a bar 1 thick and 4 long across the end.
package enum StrokeEndShape: String, CaseIterable, Equatable, Sendable {
    case none
    case arrow
    case lineArrow = "line-arrow"
    case circle
    case square
    case diamond
    case bar

    // MARK: - Property
    // How long the head is along the stroke, from its base to its tip, in units.
    package var length: Double {
        switch self {
        case .none:
            0

        case .arrow, .lineArrow, .circle, .square, .diamond:
            4

        case .bar:
            1
        }
    }

    // How wide the head is across the stroke, in units.
    package var width: Double {
        self == .none ? 0 : 4
    }

    // How far back from the tip, along the stroke, the line stops, in units: at the middle of an arrow's base, where
    // a line arrow's inner edges meet, at the centre of a circle, a square or a diamond, and at the middle of a bar.
    package var inset: Double {
        switch self {
        case .none:
            0

        case .arrow:
            4

        case .lineArrow:
            // The inner edges lie 1 inside the sides, which leave the tip at an angle whose sine is 1 / √5.
            5.squareRoot()

        case .circle, .square, .diamond:
            2

        case .bar:
            0.5
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
