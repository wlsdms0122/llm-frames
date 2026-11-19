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
    let synopsis = "<document.json> --at <t>[,<t>...] -o <out.png> [--args <args.json>]"
    let summary = "Draws the frames at the given sequence times side by side, each with its time label, without "
        + "encoding a video. The cheap check while a document is edited."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: StillOptions,
        in context: CommandContext
    ) throws {
        let document = try context.document(options.document, arguments: options.arguments, command: name)
        let resolved = try document.resolved(in: context)

        try context.exporter.still(
            resolved,
            at: options.times,
            labelFace: try context.labelFace(),
            to: options.output
        )
        try context.reportWritten(options.output)
    }

    // MARK: - Public
    // MARK: - Private
}
