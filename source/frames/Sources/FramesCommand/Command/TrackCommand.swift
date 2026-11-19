//
//  TrackCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Prints, as machine output, the quads the tracker provider follows an area found in a video along, and the motion
// fitted to each.
struct TrackCommand: Command {
    // MARK: - Property
    let name = "track"
    let synopsis = "<video> --at <t> --area <area> [--to <t>]"
    let summary = "Follows an area found at a media time backwards and forwards with the tracker provider, and "
        + "prints as JSON its quadrilateral there and on every frame followed, with the motion fitted to it."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: TrackOptions,
        in context: CommandContext
    ) throws {
        let roles = context.roles
        let reporter = TrackReporter(
            mediaFacts: roles.decoder,
            ocr: roles.ocr,
            languages: context.options.ocrLanguages,
            tracker: roles.tracker
        )
        let report = try reporter.report(of: options.video, area: options.area, at: options.time, to: options.end)

        context.output.write(JSONWriter().write(report.machineOutput))
    }

    // MARK: - Public
    // MARK: - Private
}
