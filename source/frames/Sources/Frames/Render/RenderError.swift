//
//  RenderError.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

package enum RenderError: Error, Equatable, CustomStringConvertible, Sendable {
    case outputExtension(path: String)
    case deliveryExtension(path: String)
    case deliveryOfStill(path: String)
    case timeOfMaster(path: String)
    case changedFile(path: String, place: String)
    case unreadableFile(path: String, place: String)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .outputExtension(path):
            "\(quoted(path)): render writes a .mov master or a .png frame"

        case let .deliveryExtension(path):
            "\(quoted(path)): --deliver writes an .mp4 file"

        case let .deliveryOfStill(path):
            "\(quoted(path)): --deliver writes a delivery video beside a .mov master, and a .png holds one frame"

        case let .timeOfMaster(path):
            "\(quoted(path)): --at picks the frame of a .png, and a .mov master holds every frame"

        case let .changedFile(path, place):
            "\(subject(path, place)) has changed since it was resolved, so its SHA-256 is not the pinned one"

        case let .unreadableFile(path, place):
            "\(subject(path, place)) cannot be read, so its SHA-256 cannot be checked against the pinned one"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    // A pinned file by the place that pins it.
    private func subject(
        _ path: String,
        _ place: String
    ) -> String {
        "\(place): file \(quoted(path))"
    }

    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }
}
