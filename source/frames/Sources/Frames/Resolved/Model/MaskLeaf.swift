//
//  MaskLeaf.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A leaf of a mask's geometry: its area, its box's width, height or position, its radius, or one of its points. A text
// form can give its area, its position or a point.
enum MaskLeaf: Hashable, Sendable {
    case area
    case width
    case height
    case position
    case radius
    case point(Int)
    case inTangent(Int)
    case outTangent(Int)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
