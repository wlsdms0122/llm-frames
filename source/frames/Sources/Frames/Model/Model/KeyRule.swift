//
//  KeyRule.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct KeyRule: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let type: ValueType
    let isRequired: Bool

    // MARK: - Initializer
    init(
        _ name: String,
        _ type: ValueType,
        isRequired: Bool = false
    ) {
        self.name = name
        self.type = type
        self.isRequired = isRequired
    }

    // MARK: - Public
    // MARK: - Private
}
