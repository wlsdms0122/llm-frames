//
//  MediaBorder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The border around a media clip's box: the theme `shapes.border.width` scaled, and its colour.
struct MediaBorder: Equatable, Sendable {
    // MARK: - Property
    let width: Double
    let color: Color

    // MARK: - Initializer
    init(
        width: Double,
        color: Color
    ) {
        self.width = width
        self.color = color
    }

    // MARK: - Public
    // MARK: - Private
}
