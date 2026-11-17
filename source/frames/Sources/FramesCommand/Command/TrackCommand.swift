//
//  TrackCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Prints, as machine output, the rectangles the tracker provider follows an area found in a video along.
struct TrackCommand: Command {
    // MARK: - Property
    let name = "track"

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: TrackOptions,
        in context: CommandContext
    ) throws {
        let roles = context.roles
        let reporter = TrackReporter(mediaFacts: roles.decoder, ocr: roles.ocr, tracker: roles.tracker)
        let report = try reporter.report(of: options.video, area: options.area, at: options.time, to: options.end)

        context.output.write(JSONWriter().write(report.machineOutput))
    }

    // MARK: - Public
    // MARK: - Private
}
