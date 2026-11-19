//
//  KeyGroup.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct KeyGroup: Equatable, Sendable {
    // MARK: - Property
    let keys: [String]
    // Exclusive means exactly one of the keys, otherwise at least one. Optional also takes none of them, so an
    // optional exclusive group takes at most one.
    let isExclusive: Bool
    let isOptional: Bool

    // MARK: - Initializer
    init(
        keys: [String],
        isExclusive: Bool,
        isOptional: Bool = false
    ) {
        self.keys = keys
        self.isExclusive = isExclusive
        self.isOptional = isOptional
    }

    // MARK: - Public
    // MARK: - Private
}
