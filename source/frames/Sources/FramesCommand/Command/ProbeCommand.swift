//
//  ProbeCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Prints the facts of a media file or an image sequence directory through the decoder: the text for people, or with
// `--json` the machine output.
struct ProbeCommand: Command {
    // MARK: - Property
    let name = "probe"
    let synopsis = "<media> [--json]"
    let summary = "Prints the kind, size, duration, frame rate, alpha, and audio channels and sample rate of a "
        + "medium. A fact the medium does not have is null."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: ProbeOptions,
        in context: CommandContext
    ) throws {
        let report = try ProbeReporter(mediaFacts: context.roles.decoder).report(of: options.media)

        context.output.write(options.isMachineOutput ? JSONWriter().write(report.machineOutput) : report.text + "\n")
    }

    // MARK: - Public
    // MARK: - Private
}
