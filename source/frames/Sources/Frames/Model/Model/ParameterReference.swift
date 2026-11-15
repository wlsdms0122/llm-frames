//
//  ParameterReference.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A `{"param": name}` in a template, at the place it stands for a value.
struct ParameterReference: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let name: String

    // MARK: - Initializer
    init(
        place: Place,
        name: String
    ) {
        self.place = place
        self.name = name
    }

    // MARK: - Public
    // MARK: - Private
}
