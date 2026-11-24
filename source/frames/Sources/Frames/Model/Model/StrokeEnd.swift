//
//  StrokeEnd.swift
//  Frames
//
//  Created by JSilver on 11/24/26.
//

// What a stroke draws at one of its ends: the head `shape` names, its size the stroke's width times `scale`.
package struct StrokeEnd: Equatable, Sendable {
    // MARK: - Property
    package static let none = StrokeEnd(shape: .none)
    package static let arrow = StrokeEnd(shape: .arrow)

    package let shape: StrokeEndShape
    package let scale: Double

    // MARK: - Initializer
    package init(
        shape: StrokeEndShape,
        scale: Double = 1
    ) {
        self.shape = shape
        self.scale = scale
    }

    // MARK: - Public
    // The unit its head is drawn in on a stroke `width` wide, before any shrinking: 0 where it draws no head.
    package func unit(width: Double) -> Double {
        shape == .none ? 0 : width * scale
    }

    // MARK: - Private
}
