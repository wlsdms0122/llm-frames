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
    let synopsis = "<document.json> --at <t> --point <x,y> [--args <args.json>]"
    let summary = "Prints as JSON every item under a point of the output at a sequence time, topmost first, and for "
        + "a picture of a media file the file, the media time and the pixel of the frame it shows."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: LocateOptions,
        in context: CommandContext
    ) throws {
        let document = try context.document(options.document, arguments: options.arguments, command: name)
        let resolved = try document.resolved(in: context)
        let report = try LocationReporter().report(of: resolved, at: options.time, point: options.point)

        context.output.write(JSONWriter().write(report.machineOutput))
    }

    // MARK: - Public
    // MARK: - Private
}
