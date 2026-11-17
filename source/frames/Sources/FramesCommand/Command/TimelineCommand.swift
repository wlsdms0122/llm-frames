//
//  TimelineCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Prints a document's timeline without rendering: the text for people, or with `--json` the machine output.
struct TimelineCommand: Command {
    // MARK: - Property
    let name = "timeline"

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: TimelineOptions,
        in context: CommandContext
    ) throws {
        let reporter = TimelineReporter(planner: context.planner)
        let report = switch try context.document(options.document, arguments: options.arguments, command: name) {
        case let .document(document, theme, arguments):
            try reporter.report(of: document, theme: theme, arguments: arguments)

        case let .resolved(document):
            reporter.report(of: document)
        }

        context.output.write(options.isMachineOutput ? JSONWriter().write(report.machineOutput) : report.text + "\n")
    }

    // MARK: - Public
    // MARK: - Private
}
