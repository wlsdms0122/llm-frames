//
//  PlaceholderHasher.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Gives every file an empty digest without reading it, for a resolved sequence built only to be measured, whose pins
// nothing reads.
struct PlaceholderHasher: FileHashProvider {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func sha256(ofFile path: String) throws -> String {
        ""
    }

    // MARK: - Public
    // MARK: - Private
}
