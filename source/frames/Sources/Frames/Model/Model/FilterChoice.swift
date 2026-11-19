//
//  FilterChoice.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The presets a filter choice names, as a document, a theme or a template writes it, in turn, the first applied first:
// none for `"none"`, and an op written in place names none.
struct FilterChoice: Equatable, Sendable {
    // MARK: - Property
    let presets: [PresetInstance]

    // MARK: - Initializer
    init(presets: [PresetInstance]) {
        self.presets = presets
    }

    // `place` is where the choice is written, and each preset of a list is at its index there.
    init?(
        value: JSONValue,
        place: Place
    ) {
        switch value {
        case .string("none"):
            self.init(presets: [])

        case let .array(elements):
            self.init(presets: elements.enumerated().compactMap { index, element in
                PresetInstance(value: element, place: place.appending(index: index))
            })

        case .object, .string:
            self.init(presets: PresetInstance(value: value, place: place).map { [$0] } ?? [])

        default:
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
