//
//  MaskLeaf.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A leaf of a mask's geometry that a text form can give: its area, its box's position, or one of its points.
enum MaskLeaf: Hashable, Sendable {
    case area
    case position
    case point(Int)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
