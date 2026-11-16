//
//  PinnedFile.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A file a role opens, by its absolute path and the SHA-256 of its bytes as 64 lower case hexadecimal digits.
struct PinnedFile: Equatable, Sendable {
    // MARK: - Property
    let path: String
    let sha256: String

    // MARK: - Initializer
    init(
        path: String,
        sha256: String
    ) {
        self.path = path
        self.sha256 = sha256
    }

    // MARK: - Public
    // MARK: - Private
}
