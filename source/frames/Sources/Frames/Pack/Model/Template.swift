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
    let parameters: [Parameter]
    let references: [ParameterReference]

    // A document read as a template is one only when it declares `params`, even none, so a plain document is not.
    var declaresParameters: Bool {
        document.objectValue?.contains("params") == true
    }

    // MARK: - Initializer
    init(
        document: JSONValue,
        place: Place,
        parameters: [Parameter],
        references: [ParameterReference]
    ) {
        self.document = document
        self.place = place
        self.parameters = parameters
        self.references = references
    }

    // MARK: - Public
    // MARK: - Private
}
