//
//  ProbeFailure.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

// Why a fake probe cannot read a file that is there.
struct ProbeFailure: Error, CustomStringConvertible, Sendable {
    // MARK: - Property
    let description: String

    // MARK: - Initializer
    init(_ description: String) {
        self.description = description
    }

    // MARK: - Public
    // MARK: - Private
}
