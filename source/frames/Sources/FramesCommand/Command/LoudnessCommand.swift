//
//  LoudnessCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/21/26.
//

import Frames

// Measures the loudness and peaks of one mix with the mixer role, without rendering pictures: a document's mix, or
// the mix of one clip of a medium. A `.json` file, a pack template or `-` is a document, which it resolves first, and
// any other path a medium, which takes no `--args`. It prints the text for people, or with `--json` the machine output,
// and writes no file.
struct LoudnessCommand: Command {
    // MARK: - Property
    let name = "loudness"
    let synopsis = "<media | document.json> [--from <t>] [--to <t>] [--args <args.json>] [--json]"
    let summary = "Measures the integrated loudness, loudness range, largest momentary and short-term loudness, true "
        + "peak and sample peak of a document's mix, or of the mix of one clip of a medium. A measure the meter gives "
        + "none of is null."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: LoudnessOptions,
        in context: CommandContext
    ) throws {
        let roles = context.roles
        let reporter = LoudnessReporter(decoder: roles.decoder, mixer: roles.mixer, mediaFacts: roles.decoder)
        let loudness: Loudness
        // The argument is told apart as `sheet` and `extract` tell theirs, its path a medium here.
        switch FrameSourceArgument(options.source) {
        case let .document(argument):
            let document = try context.document(argument, arguments: options.arguments, command: name)
            loudness = try reporter.loudness(of: try document.resolved(in: context), from: options.from, to: options.to)

        case let .video(path):
            guard options.arguments == nil else { throw CommandError.argumentsOfMedium(command: name, path: path) }
            loudness = try reporter.loudness(ofMedium: path, from: options.from, to: options.to)
        }

        context.output.write(options.isMachineOutput ? JSONWriter().write(loudness.machineOutput) : loudness.text + "\n")
    }

    // MARK: - Public
    // MARK: - Private
}
