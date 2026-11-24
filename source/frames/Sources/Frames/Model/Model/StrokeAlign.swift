//
//  StrokeAlign.swift
//  Frames
//
//  Created by JSilver on 11/24/26.
//

// The side of its outline a stroke's width lies on: inside it, centred on it with half on each side, or outside it.
// A stroke on one side is the centred stroke of twice its width, cut to that side of the outline.
package enum StrokeAlign: String, CaseIterable, Equatable, Sendable {
    case inside
    case center
    case outside

    // MARK: - Property
    // How far past the outline it reaches, in times its width.
    package var reach: Double {
        switch self {
        case .inside:
            0

        case .center:
            0.5

        case .outside:
            1
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // The width of the centred stroke a stroke `width` wide is cut from.
    package func tracedWidth(of width: Double) -> Double {
        self == .center ? width : 2 * width
    }

    // MARK: - Private
}
