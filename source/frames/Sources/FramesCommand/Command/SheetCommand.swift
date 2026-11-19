//
//  SheetCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Lays the frames of a video or a document over a range out on one PNG, each labelled with its time.
struct SheetCommand: Command {
    // MARK: - Property
    let name = "sheet"
    let synopsis = "<video | document.json> -o <out.png> [--from <t>] [--to <t>] [--step 1] "
        + "[--cols \(SheetOptions.defaultColumns)]"
    let summary = "Lays frames out in one PNG, each at most 480 pixels on its longer side and labelled with its "
        + "time, left to right in columns, then top to bottom. A document gives its frames at sequence times "
        + "as still draws them, and a video the frames shown at media times."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: SheetOptions,
        in context: CommandContext
    ) throws {
        let source = try context.frameSource(FrameSourceArgument(options.source), command: name)

        try context.exporter.sheet(
            source,
            range: options.range,
            columns: options.columns,
            labelFace: try context.labelFace(),
            to: options.output
        )
        try context.reportWritten(options.output)
    }

    // MARK: - Public
    // MARK: - Private
}
