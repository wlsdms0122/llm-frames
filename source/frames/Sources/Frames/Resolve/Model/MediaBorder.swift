//
//  MediaBorder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The border along the edge of a box at one instant, its width in output pixels, on the side of the edge `align` names,
// drawn as a stroke with miter joins along the box's outline with its corners rounded.
package struct MediaBorder: Equatable, Sendable {
    // MARK: - Property
    package let width: Double
    package let color: Color
    package let align: StrokeAlign

    // MARK: - Initializer
    package init(
        width: Double,
        color: Color,
        align: StrokeAlign = .inside
    ) {
        self.width = width
        self.color = color
        self.align = align
    }

    // MARK: - Public
    // MARK: - Private
}
