//
//  TextAlignment.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Text is laid out left to right, so an alignment names a physical side.
enum TextAlignment: String, Equatable, Sendable {
    case left
    case center
    case right

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Where a line `width` wide starts inside `room`.
    func offset(
        of width: Double,
        in room: Double
    ) -> Double {
        switch self {
        case .left:
            0

        case .center:
            (room - width) / 2

        case .right:
            room - width
        }
    }

    // MARK: - Private
}
