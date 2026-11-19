//
//  Place+Leaf.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A leaf a keyframe writes, by its path below the keyframe. One keyframe's leaf is another's when either path holds the
// other, since `true` or `null` for a value writes every leaf in it.
extension Place {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func isLeaf(of other: Place) -> Bool {
        components.starts(with: other.components) || other.components.starts(with: components)
    }

    // MARK: - Private
}
