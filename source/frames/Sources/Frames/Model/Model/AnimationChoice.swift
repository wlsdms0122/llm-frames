//
//  AnimationChoice.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// An animation choice as a document, a theme or a template writes it. `split` takes the entrance from one preset and
// the exit from another, and a side that is nil, written `"none"`, has none.
enum AnimationChoice: Equatable, Sendable {
    case none
    case preset(PresetInstance)
    case split(entrance: PresetInstance?, exit: PresetInstance?)

    // MARK: - Property
    // MARK: - Initializer
    // `place` is where the choice is written.
    init?(
        value: JSONValue,
        place: Place
    ) {
        guard value != .string("none") else {
            self = .none
            return
        }
        if let object = value.objectValue, let entrance = object["entrance"], let exit = object["exit"] {
            self = .split(
                entrance: Self.side(entrance, place: place.appending(key: "entrance")),
                exit: Self.side(exit, place: place.appending(key: "exit"))
            )
            return
        }
        guard let instance = PresetInstance(value: value, place: place) else { return nil }

        self = .preset(instance)
    }

    // MARK: - Public
    // MARK: - Private
    private static func side(
        _ value: JSONValue,
        place: Place
    ) -> PresetInstance? {
        guard value != .string("none") else { return nil }

        return PresetInstance(value: value, place: place)
    }
}
