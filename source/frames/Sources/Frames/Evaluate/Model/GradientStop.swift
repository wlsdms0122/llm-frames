//
//  GradientStop.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

package struct GradientStop: Equatable, Sendable {
    // MARK: - Property
    package let offset: Double
    package let color: Color

    // MARK: - Initializer
    package init(
        offset: Double,
        color: Color
    ) {
        self.offset = offset
        self.color = color
    }

    // MARK: - Public
    // MARK: - Private
}
