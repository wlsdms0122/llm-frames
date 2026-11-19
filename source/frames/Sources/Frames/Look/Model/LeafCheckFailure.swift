//
//  LeafCheckFailure.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// How a value breaks its `LeafCheck`. A member's failure names the member's key, where the stop is placed.
enum LeafCheckFailure: Equatable, Sendable {
    case unknownName(String, allowed: [String])
    case wrongValue
    case invalidMember(key: String, reason: String)
    // The member's value is not a whole number 0 or more.
    case wrongMember(key: String)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
