//
//  PinnedReferenceError.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// A pinned file that is not the file a resolved document was resolved against. `place` is the entry that pins it.
package enum PinnedReferenceError: Error, Equatable, CustomStringConvertible, Sendable {
    case changedFile(path: String, place: String)
    case unreadableFile(path: String, place: String)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .changedFile(path, place):
            "\(subject(path, place)) has changed since it was resolved, so its SHA-256 is not the pinned one"

        case let .unreadableFile(path, place):
            "\(subject(path, place)) cannot be read, so its SHA-256 cannot be checked against the pinned one"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func subject(
        _ path: String,
        _ place: String
    ) -> String {
        "\(place): file \(JSONValue.string(path).written)"
    }
}
