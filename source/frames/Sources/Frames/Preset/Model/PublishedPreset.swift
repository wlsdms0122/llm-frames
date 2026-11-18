//
//  PublishedPreset.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A preset checked against its parameter types, with the parameters it publishes and where they are referred to,
// and read with every parameter at its default. A choice with arguments fills them in from here, so the preset is
// checked once however many choices name it.
struct PublishedPreset<Preset: Sendable>: Sendable {
    // MARK: - Property
    let value: JSONValue
    let place: Place
    let parameters: [Parameter]
    let references: [ParameterReference]
    let defaults: Preset

    // MARK: - Initializer
    init(
        value: JSONValue,
        place: Place,
        parameters: [Parameter],
        references: [ParameterReference],
        defaults: Preset
    ) {
        self.value = value
        self.place = place
        self.parameters = parameters
        self.references = references
        self.defaults = defaults
    }

    // MARK: - Public
    // MARK: - Private
}
