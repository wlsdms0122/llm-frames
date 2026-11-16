//
//  JSONValue+Time.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Machine output writes every time and length to the nearest microsecond, so floating point noise stays out of it.
// A microsecond is far below a frame at any rate, so no frame changes.
extension JSONValue {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    static func time(_ seconds: Double) -> JSONValue {
        .number((seconds * 1_000_000).rounded() / 1_000_000)
    }

    // MARK: - Private
}
