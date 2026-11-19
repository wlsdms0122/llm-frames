//
//  LookMember.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

struct LookMember: Equatable, Sendable {
    // MARK: - Property
    let key: String
    let value: LookValue

    // MARK: - Initializer
    init(
        key: String,
        value: LookValue
    ) {
        self.key = key
        self.value = value
    }

    // MARK: - Public
    // MARK: - Private
}
