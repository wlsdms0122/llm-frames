//
//  StillCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Draws sequence frames at the times `--at` gives side by side, each labelled with its time, to one PNG, without
// encoding a video.
struct StillCommand: Command {
    // MARK: - Property
    let name = "still"

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: StillOptions,
        in context: CommandContext
    ) throws {
        let document = try context.document(options.document, arguments: options.arguments, command: name)
        let resolved = try document.resolved(by: context.planner)

        try context.exporter.still(resolved, at: options.times, to: options.output)
        try context.reportWritten(options.output)
    }

    // MARK: - Public
    // MARK: - Private
}
