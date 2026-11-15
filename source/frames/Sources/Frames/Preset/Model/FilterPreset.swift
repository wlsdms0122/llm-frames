//
//  FilterPreset.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct FilterPreset: Equatable, Sendable {
    // MARK: - Property
    let description: String
    let operations: [FilterOperation]

    // MARK: - Initializer
    init(description: String, operations: [FilterOperation]) {
        self.description = description
        self.operations = operations
    }

    // MARK: - Public
    // MARK: - Private
}
