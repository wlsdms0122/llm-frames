//
//  AnimationChoice.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// An animation choice as a document, a theme or a template writes it. `by`, `stagger` and `order` are as written, nil
// where absent, and resolve checks them. `split` takes the entrance from one preset and the exit from another, and a side
// that is nil, written `"none"`, has none.
enum AnimationChoice: Equatable, Sendable {
    case none
    case preset(PresetInstance, by: TextUnit?, stagger: Double?, order: UnitOrder?)
    case split(entrance: PresetInstance?, exit: PresetInstance?, by: TextUnit?, stagger: Double?, order: UnitOrder?)

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
        let object = value.objectValue
        let by = object?["by"]?.stringValue.flatMap(TextUnit.init(rawValue:))
        let stagger = object?["stagger"]?.numberValue
        let order = object?["order"]?.stringValue.flatMap(UnitOrder.init(rawValue:))
        if let entrance = object?["entrance"], let exit = object?["exit"] {
            self = .split(
                entrance: Self.side(entrance, place: place.appending(key: "entrance")),
                exit: Self.side(exit, place: place.appending(key: "exit")),
                by: by,
                stagger: stagger,
                order: order
            )
            return
        }
        guard let instance = PresetInstance(value: value, place: place) else { return nil }

        self = .preset(instance, by: by, stagger: stagger, order: order)
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
