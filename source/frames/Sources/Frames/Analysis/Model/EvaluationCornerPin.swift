//
//  EvaluationCornerPin.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// One corner pin that carries an item `evaluate` reports: its picture's `dest`, as its four corners, and its picture's
// corner pin, both carried by the picture's transform and the maps of the pictures that hold it, their corner pins left
// out, into the coordinates the item's transform gives. H(destination → cornerPin) carries a point on from there
// (FRAMES-23 Item transforms).
package struct EvaluationCornerPin: Equatable, Sendable {
    // MARK: - Property
    package let destination: Quad
    package let cornerPin: Quad

    // MARK: - Initializer
    init(
        destination: Quad,
        cornerPin: Quad
    ) {
        self.destination = destination
        self.cornerPin = cornerPin
    }

    // MARK: - Public
    // MARK: - Private
}
