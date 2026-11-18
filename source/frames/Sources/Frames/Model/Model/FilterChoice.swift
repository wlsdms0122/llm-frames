//
//  FilterChoice.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A filter choice as a document, a theme or a template writes it: the presets it applies in turn, the first applied
// first, and none for `"none"`.
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
            let presets = elements.enumerated().compactMap { index, element in
                PresetInstance(value: element, place: place.appending(index: index))
            }
            guard presets.count == elements.count else { return nil }

            self.init(presets: presets)

        default:
            guard let instance = PresetInstance(value: value, place: place) else { return nil }

            self.init(presets: [instance])
        }
    }

    // MARK: - Public
    // MARK: - Private
}
