//
//  MediaBorder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The border inside a box at one instant, in output pixels.
package struct MediaBorder: Equatable, Sendable {
    // MARK: - Property
    package let width: Double
    package let color: Color

    // MARK: - Initializer
    package init(
        width: Double,
        color: Color
    ) {
        self.width = width
        self.color = color
    }

    // MARK: - Public
    // MARK: - Private
}
