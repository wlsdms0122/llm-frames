//
//  LocateCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Prints, as machine output, what drew a point of a document's output at a sequence time, topmost first.
struct LocateCommand: Command {
    // MARK: - Property
    let name = "locate"

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: LocateOptions,
        in context: CommandContext
    ) throws {
        let document = try context.document(options.document, arguments: options.arguments, command: name)
        let resolved = try document.resolved(by: context.planner)
        let report = LocationReporter().report(of: resolved, at: options.time, point: options.point)

        context.output.write(JSONWriter().write(report.machineOutput))
    }

    // MARK: - Public
    // MARK: - Private
}
