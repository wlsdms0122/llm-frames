//
//  ParameterReference.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A `{"param": name}` in a template, at the place it stands for a value, with the type and kind that place takes, so
// a value given for it can be checked as if written there.
struct ParameterReference: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let name: String
    let type: ValueType
    let kind: String

    // MARK: - Initializer
    init(
        place: Place,
        name: String,
        type: ValueType,
        kind: String
    ) {
        self.place = place
        self.name = name
        self.type = type
        self.kind = kind
    }

    // MARK: - Public
    // MARK: - Private
}
