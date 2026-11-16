//
//  KeyframedValues.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A title or media clip's keyframes sampled at one instant, before its animation: `position`, the top left of its box
// in output pixels, its scale and rotation in degrees, and its opacity.
struct KeyframedValues: Equatable, Sendable {
    // MARK: - Property
    let position: Point
    let scale: Double
    let rotation: Double
    let opacity: Double

    // MARK: - Initializer
    init(
        position: Point,
        scale: Double = 1,
        rotation: Double = 0,
        opacity: Double = 1
    ) {
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
    }

    // MARK: - Public
    // MARK: - Private
}
