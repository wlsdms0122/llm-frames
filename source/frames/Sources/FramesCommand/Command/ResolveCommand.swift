//
//  ResolveCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Writes the resolved document of a document, a template with its arguments, or a resolved document as it is.
struct ResolveCommand: Command {
    // MARK: - Property
    let name = "resolve"

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: ResolveOptions,
        in context: CommandContext
    ) throws {
        let document = try context.document(options.document, arguments: options.arguments, command: name)
        let resolved = try document.resolved(by: context.planner)

        try context.write(ResolvedDocumentWriter().write(resolved), to: options.output)
        try context.reportWritten(options.output)
    }

    // MARK: - Public
    // MARK: - Private
}
