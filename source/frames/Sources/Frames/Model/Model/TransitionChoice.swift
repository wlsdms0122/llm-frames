//
//  TransitionChoice.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A transition choice as a document or theme writes it.
enum TransitionChoice: Equatable, Sendable {
    case cut
    case preset(String)
    case timed(preset: String, seconds: Double)

    // MARK: - Property
    // MARK: - Initializer
    init?(value: JSONValue) {
        switch value {
        case .string("cut"):
            self = .cut

        case let .string(name):
            self = .preset(name)

        case let .object(object):
            guard let name = object["preset"]?.stringValue, let seconds = object["seconds"]?.numberValue else { return nil }

            self = .timed(preset: name, seconds: seconds)

        default:
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
