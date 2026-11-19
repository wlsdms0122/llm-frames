//
//  DocumentInput.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// The document a command was given: a document to plan with the theme and arguments it was given, in the pack it is
// read from, or a resolved document, used as it is.
enum DocumentInput: Sendable {
    case document(JSONValue, pack: String?, theme: String?, arguments: ArgumentFile?)
    case resolved(ResolvedSequence)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func resolved(in context: CommandContext) throws -> ResolvedSequence {
        switch self {
        case let .document(document, pack, theme, arguments):
            try context.planner(in: pack).resolved(document, theme: theme, arguments: arguments)

        case let .resolved(sequence):
            sequence
        }
    }

    // MARK: - Private
}
