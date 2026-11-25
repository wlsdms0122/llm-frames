//
//  StrokeEnd.swift
//  Frames
//
//  Created by JSilver on 11/24/26.
//

// What a stroke draws at one of its ends: `head`, nil for none, its size the stroke's width times `scale`.
package struct StrokeEnd: Equatable, Sendable {
    // MARK: - Property
    package static let none = StrokeEnd(head: nil)

    package let head: StrokeHead?
    package let scale: Double

    // MARK: - Initializer
    package init(
        head: StrokeHead?,
        scale: Double = 1
    ) {
        self.head = head
        self.scale = scale
    }

    // MARK: - Public
    // The unit its head is drawn in on a stroke `width` wide, before any shrinking: 0 where it draws no head.
    package func unit(width: Double) -> Double {
        head == nil ? 0 : width * scale
    }

    // How long its head is along the stroke, in units, 0 for none.
    package var length: Double {
        head?.length ?? 0
    }

    // MARK: - Private
}
