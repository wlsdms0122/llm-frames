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
    let synopsis = "<document.json> [--args <args.json>] [--json]"
    let summary = "Resolves without rendering and prints the plan of time: every storyline clip's edit, drawn and "
        + "clip ranges, speed and incoming transition, and every other clip's visible range, kind, lane, "
        + "animation, place and parent. It writes no file."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: TimelineOptions,
        in context: CommandContext
    ) throws {
        let report = switch try context.document(options.document, arguments: options.arguments, command: name) {
        case let .document(document, pack, theme, arguments):
            try TimelineReporter(planner: context.planner(in: pack))
                .report(of: document, theme: theme, arguments: arguments)

        case let .resolved(document):
            TimelineReporter(planner: context.planner(in: nil)).report(of: document)
        }

        context.output.write(options.isMachineOutput ? JSONWriter().write(report.machineOutput) : report.text + "\n")
    }

    // MARK: - Public
    // MARK: - Private
}
