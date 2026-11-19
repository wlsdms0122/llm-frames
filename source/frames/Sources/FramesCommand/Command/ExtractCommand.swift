//
//  ExtractCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Writes the frames of a video or a document over a range as PNG files in a directory, one line for each.
struct ExtractCommand: Command {
    // MARK: - Property
    let name = "extract"
    let synopsis = "<video | document.json> <outdir> [--from <t>] [--to <t>] [--step 1]"
    let summary = "Writes frames as full-size PNG files named by their index, 0000.png, 0001.png and on. A document "
        + "gives its frames at sequence times as still draws them, and a video the frames shown at media "
        + "times."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: ExtractOptions,
        in context: CommandContext
    ) throws {
        let source = try context.frameSource(FrameSourceArgument(options.source), command: name)

        for path in try context.exporter.extract(source, range: options.range, to: options.directory) {
            try context.reportWritten(path)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
