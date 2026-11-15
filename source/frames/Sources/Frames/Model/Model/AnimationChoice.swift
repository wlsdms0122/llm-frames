//
//  AnimationChoice.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// An animation choice as a document or theme writes it. `split` takes the entrance from one preset and the exit
// from another, and `"none"` on a side leaves that side without one.
enum AnimationChoice: Equatable, Sendable {
    case none
    case preset(String)
    case split(entrance: String, exit: String)

    // MARK: - Property
    // MARK: - Initializer
    init?(value: JSONValue) {
        switch value {
        case .string("none"):
            self = .none

        case let .string(name):
            self = .preset(name)

        case let .object(object):
            guard let entrance = object["entrance"]?.stringValue, let exit = object["exit"]?.stringValue else { return nil }

            self = .split(entrance: entrance, exit: exit)

        default:
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
