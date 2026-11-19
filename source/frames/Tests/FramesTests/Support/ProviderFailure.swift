//
//  ProviderFailure.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

// The message a failing fake provider gives.
struct ProviderFailure: Error, CustomStringConvertible, Sendable {
    // MARK: - Property
    let description: String

    // MARK: - Initializer
    init(_ description: String) {
        self.description = description
    }

    // MARK: - Public
    // MARK: - Private
}
