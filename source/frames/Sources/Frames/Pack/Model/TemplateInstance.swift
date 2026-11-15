//
//  TemplateInstance.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A template with its arguments filled in: a document of plain values. `arguments` are the places, from the top of
// the document, where media given as an argument stands, since that media keeps the look of the document that gave it.
struct TemplateInstance: Equatable, Sendable {
    // MARK: - Property
    let document: JSONValue
    let kind: MediaKind
    let arguments: [Place]

    // MARK: - Initializer
    init(
        document: JSONValue,
        kind: MediaKind,
        arguments: [Place]
    ) {
        self.document = document
        self.kind = kind
        self.arguments = arguments
    }

    // MARK: - Public
    // MARK: - Private
}
