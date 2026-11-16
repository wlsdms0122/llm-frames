//
//  DocumentInput.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// The document a command was given: a document to plan with the theme and arguments it was given, or a resolved
// document, used as it is.
enum DocumentInput: Sendable {
    case document(JSONValue, theme: String?, arguments: ArgumentFile?)
    case resolved(ResolvedDocument)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func resolved(by planner: DocumentPlanner) throws -> ResolvedDocument {
        switch self {
        case let .document(document, theme, arguments):
            try planner.resolved(document, theme: theme, arguments: arguments)

        case let .resolved(document):
            document
        }
    }

    // MARK: - Private
}
