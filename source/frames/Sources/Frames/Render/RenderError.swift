//
//  RenderError.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

package enum RenderError: Error, Equatable, CustomStringConvertible, Sendable {
    case outputExtension(path: String)
    case deliveryExtension(path: String)
    case deliveryWithoutMaster(path: String)
    case timeOfVideo(path: String)
    case sampledFrame(time: Double, reason: String)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .outputExtension(path):
            "\(quoted(path)): render writes a .mov master, an .mp4 delivery or a .png frame"

        case let .deliveryExtension(path):
            "\(quoted(path)): --deliver writes an .mp4 file"

        case let .deliveryWithoutMaster(path):
            "\(quoted(path)): --deliver writes a delivery video beside a .mov master, and -o is not a .mov"

        case let .timeOfVideo(path):
            "\(quoted(path)): --at picks the frame of a .png, and a video holds every frame"

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
