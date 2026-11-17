//
//  OptionRule.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// An option a command takes: its name and, for one that takes a value, the value's placeholder as usage writes it. An
// option without a placeholder is a flag.
struct OptionRule: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let value: String?

    // MARK: - Initializer
    init(
        _ name: String,
        value: String? = nil
    ) {
        self.name = name
        self.value = value
    }

    // MARK: - Public
    // MARK: - Private
}
