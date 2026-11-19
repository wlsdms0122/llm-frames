//
//  AudioPreset.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// An audio preset with its parameters filled: its ops as written, each in its range.
struct AudioPreset: Equatable, Sendable {
    // MARK: - Property
    let description: String
    let operations: [JSONObject]

    // MARK: - Initializer
    init(description: String, operations: [JSONObject]) {
        self.description = description
        self.operations = operations
    }

    // MARK: - Public
    // MARK: - Private
}
