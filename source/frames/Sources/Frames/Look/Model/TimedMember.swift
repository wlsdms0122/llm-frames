//
//  TimedMember.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

struct TimedMember: Equatable, Sendable {
    // MARK: - Property
    let key: String
    let value: TimedValue

    // MARK: - Initializer
    init(
        key: String,
        value: TimedValue
    ) {
        self.key = key
        self.value = value
    }

    // MARK: - Public
    // MARK: - Private
}
