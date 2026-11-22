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
    case sampledFrame(time: Double, reason: String)

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

        case let .sampledFrame(time, reason):
            "the frame at \(JSONValue.time(time).written) is given as samples of its exposure: \(reason)"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }
}
