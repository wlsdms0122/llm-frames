//
//  FollowedKey.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A key of a tracked clip's geometry whose values its track carries (FRAMES-12 What is tracked): on its own media its
// crop and mask, and on its parent's media its area, points, position and corner pin, and a shape's or an adjustment's
// mask.
enum FollowedKey: Hashable, Sendable {
    case area
    case points
    case position
    case cornerPin
    case crop
    case mask

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
