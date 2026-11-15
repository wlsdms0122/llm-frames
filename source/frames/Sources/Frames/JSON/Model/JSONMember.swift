//
//  JSONMember.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct JSONMember: Equatable, Sendable {
    // MARK: - Property
    let key: String
    let value: JSONValue

    // MARK: - Initializer
    init(key: String, value: JSONValue) {
        self.key = key
        self.value = value
    }

    // MARK: - Public
    // MARK: - Private
}
