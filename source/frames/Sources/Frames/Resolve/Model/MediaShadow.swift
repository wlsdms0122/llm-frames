//
//  MediaShadow.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The theme shadow under a media clip's box: the standard deviation of its blur and its offset, both scaled, and its
// colour.
struct MediaShadow: Equatable, Sendable {
    // MARK: - Property
    let radius: Double
    let offset: Point
    let color: Color

    // MARK: - Initializer
    init(
        radius: Double,
        offset: Point,
        color: Color
    ) {
        self.radius = radius
        self.offset = offset
        self.color = color
    }

    // MARK: - Public
    // MARK: - Private
}
