//
//  TrackCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Prints, as machine output, the track data of an area the tracker provider follows in a video: the quads it follows
// the area along, which a clip's `track` takes.
struct TrackCommand: Command {
    // MARK: - Property
    let name = "track"
    let synopsis = "<video> --at <t> --area <area> [--to <t>] [--color-space <name>]"
    let summary = "Follows an area on the frame at a media time backwards and forwards with the tracker provider, and "
        + "prints as JSON the track data a clip's track takes: its quadrilateral on every frame followed."

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
            tracker: roles.tracker
        )
        let report = try reporter.report(
            of: options.video,
            area: options.area,
            at: options.time,
            to: options.end,
            colorSpace: options.colorSpace
        )

        context.output.write(JSONWriter().write(report.machineOutput))
    }

    // MARK: - Public
    // MARK: - Private
}
