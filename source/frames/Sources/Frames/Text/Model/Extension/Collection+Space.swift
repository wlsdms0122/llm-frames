//
//  Collection+Space.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The Unicode scalars of a grapheme cluster.
extension Collection where Element == Unicode.Scalar {
    // MARK: - Property
    // Whether the cluster is a space: its first scalar is `White_Space`, whatever follows it.
    var isSpace: Bool {
        first?.properties.isWhitespace ?? false
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
