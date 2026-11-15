//
//  Template.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A template checked against its parameter types, with the place of every reference to a parameter in it.
struct Template: Equatable, Sendable {
    // MARK: - Property
    let document: DocumentFile
    let parameters: [TemplateParameter]
    let references: [ParameterReference]

    // MARK: - Initializer
    init(
        document: DocumentFile,
        parameters: [TemplateParameter],
        references: [ParameterReference]
    ) {
        self.document = document
        self.parameters = parameters
        self.references = references
    }

    // MARK: - Public
    // MARK: - Private
}
