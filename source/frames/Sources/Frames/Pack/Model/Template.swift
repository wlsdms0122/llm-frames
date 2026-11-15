//
//  Template.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A template checked against its parameter types, with the place of every reference to a parameter in it. `place` is
// where it is written: the top level of its file, or of the document when a command is given a template.
struct Template: Equatable, Sendable {
    // MARK: - Property
    let document: JSONValue
    let place: Place
    let kind: MediaKind
    let parameters: [TemplateParameter]
    let references: [ParameterReference]

    // MARK: - Initializer
    init(
        document: JSONValue,
        place: Place,
        kind: MediaKind,
        parameters: [TemplateParameter],
        references: [ParameterReference]
    ) {
        self.document = document
        self.place = place
        self.kind = kind
        self.parameters = parameters
        self.references = references
    }

    // MARK: - Public
    // MARK: - Private
}
