//
//  PresetInstance.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A preset as a choice names it: by its name, with the arguments the choice passes it, and the place the choice is
// written, which a stop on those arguments names. Arguments that are sampled, one keyframe's of a key of two or more,
// may put a length or size at 0.
struct PresetInstance: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let arguments: JSONObject
    let place: Place
    let isSampled: Bool

    // MARK: - Initializer
    init(
        name: String,
        arguments: JSONObject = JSONObject(),
        place: Place = .root,
        isSampled: Bool = false
    ) {
        self.name = name
        self.arguments = arguments
        self.place = place
        self.isSampled = isSampled
    }

    // A preset name, or `{preset, args}`, as it passed the shape check of its choice.
    init?(
        value: JSONValue,
        place: Place
    ) {
        switch value {
        case let .string(name):
            self.init(name: name, place: place)

        case let .object(object):
            guard let name = object["preset"]?.stringValue else { return nil }

            self.init(name: name, arguments: object["args"]?.objectValue ?? JSONObject(), place: place)

        default:
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
