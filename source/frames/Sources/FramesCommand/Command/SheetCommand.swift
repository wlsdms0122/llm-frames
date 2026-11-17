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

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: SheetOptions,
        in context: CommandContext
    ) throws {
        let source = try context.frameSource(FrameSourceArgument(options.source), command: name)

        try context.exporter().sheet(source, range: options.range, columns: options.columns, to: options.output)
        try context.reportWritten(options.output)
    }

    // MARK: - Public
    // MARK: - Private
}
