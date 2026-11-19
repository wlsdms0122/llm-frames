//
//  ValueStructure.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The type of a value of a look: how it is read, merged and timed. Declaring a keyframable value is declaring its
// structure; the look merge and timing walk it and hold no code for any one key.
//
// A `forms` value is one of several forms, named: a string is the `color` form, and an object of one key that names a
// form is that form. A `choice` is a preset choice: a string or an object naming `preset` or `op` is that form, an
// object naming neither is partial and merges over the form below, and `offNames` turn it off. A form's other keys
// are `anyValue`: a value whose structure is not declared, which merges key by key at every depth and is never timed.
indirect enum ValueStructure: Sendable {
    case anyValue
    case leaf(LeafKind)
    case object(ObjectStructure)
    case map(ValueStructure)
    case list(ValueStructure)
    case forms([(name: String, structure: ValueStructure)])
    case choice(offNames: [String])

    // MARK: - Property
    // The name of the form a string takes.
    static let colorForm = "color"

    // MARK: - Initializer
    // MARK: - Public
    func structure(ofForm name: String) -> ValueStructure? {
        switch self {
        case let .forms(forms):
            forms.first { $0.name == name }?.structure

        case .choice:
            .anyValue

        case .anyValue, .leaf, .object, .map, .list:
            nil
        }
    }

    // MARK: - Private
}
