//
//  EvaluateCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Prints, as machine output, the display list of a document at a sequence time, with the clip or op that drew each
// item.
struct EvaluateCommand: Command {
    // MARK: - Property
    let name = "evaluate"

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: EvaluateOptions,
        in context: CommandContext
    ) throws {
        let document = try context.document(options.document, arguments: options.arguments, command: name)
        let report = EvaluationReporter().report(of: try document.resolved(by: context.planner), at: options.time)

        context.output.write(JSONWriter().write(report.machineOutput))
    }

    // MARK: - Public
    // MARK: - Private
}
