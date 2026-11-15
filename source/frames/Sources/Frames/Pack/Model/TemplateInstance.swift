//
//  TemplateInstance.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A template with its arguments filled in: a document of plain values. `arguments` are the places, from the top of
// the document, where media given as an argument stands, with the parameter it was given for, since that media keeps
// the look of the document that gave it. `values` are what every parameter takes, its argument or its default.
struct TemplateInstance: Equatable, Sendable {
    // MARK: - Property
    let document: JSONValue
    let kind: MediaKind
    let arguments: [ParameterReference]
    let values: [String: JSONValue]

    // MARK: - Initializer
    init(
        document: JSONValue,
        kind: MediaKind,
        arguments: [ParameterReference],
        values: [String: JSONValue]
    ) {
        self.document = document
        self.kind = kind
        self.arguments = arguments
        self.values = values
    }

    // MARK: - Public
    // MARK: - Private
}
