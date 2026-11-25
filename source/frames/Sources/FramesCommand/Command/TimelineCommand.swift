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
    let synopsis = "<document.json> [--at <t>] [--nested <place>] [--args <args.json>] [--json]"
    let summary = "Resolves without rendering and prints the plan of time: every clip's kind and media, every "
        + "storyline clip's edit, drawn and clip ranges, speed and incoming transition, and every other clip's "
        + "visible range, lane, animation, place and parent. With --at it also gives each clip's clip time and "
        + "media time there, and where its box and its masks lie in output pixels. With --nested it reports the "
        + "sequence nested at a place on its own clock. It writes no file."

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
                .report(of: document, theme: theme, arguments: arguments, at: options.time, nested: options.nested)

        case let .resolved(document):
            try report(of: document, options: options, in: context)
        }

        context.output.write(options.isMachineOutput ? JSONWriter().write(report.machineOutput) : report.text + "\n")
    }

    // MARK: - Public
    // MARK: - Private
    private func report(
        of document: ResolvedSequence,
        options: TimelineOptions,
        in context: CommandContext
    ) throws -> TimelineReport {
        let reporter = TimelineReporter(planner: context.planner(in: nil))
        guard let place = options.nested else { return reporter.report(of: document, at: options.time) }

        return try reporter.report(of: document, nested: place, at: options.time)
    }
}
