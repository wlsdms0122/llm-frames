//
//  KeyGroup.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct KeyGroup: Equatable, Sendable {
    // MARK: - Property
    let keys: [String]
    // Exclusive means exactly one of the keys, otherwise at least one.
    let isExclusive: Bool

    // MARK: - Initializer
    init(keys: [String], isExclusive: Bool) {
        self.keys = keys
        self.isExclusive = isExclusive
    }

    // MARK: - Public
    // MARK: - Private
}
