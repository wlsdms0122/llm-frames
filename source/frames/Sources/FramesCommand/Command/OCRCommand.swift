//
//  OCRCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Prints the lines the OCR provider recognises in a still or in video frames, in the recognition languages of
// `--languages`: the text for people, or with `--json` the machine output.
struct OCRCommand: Command {
    // MARK: - Property
    let name = "ocr"
    let synopsis = "<still | video> [--page <n>] [--at <t> | --from <t> --to <t> --step <s>] "
        + "[--languages <tag>[,<tag>...]] [--color-space <name>] [--json]"
    let summary = "Prints the picture's size, then each recognised line as [x, y, w, h] and its text in media "
        + "pixels, for a page of a PDF in points, top to bottom by row and left to right within a row. Over a "
        + "range it does this for each frame, under its media time."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: OCROptions,
        in context: CommandContext
    ) throws {
        let roles = context.roles
        let reporter = OCRReporter(
            mediaFacts: roles.decoder,
            ocr: roles.ocr,
            languages: options.languages
        )
        let report = try reporter.report(
            of: options.media,
            page: options.page,
            at: options.selection,
            colorSpace: options.colorSpace
        )

        context.output.write(options.isMachineOutput ? JSONWriter().write(report.machineOutput) : report.text + "\n")
    }

    // MARK: - Public
    // MARK: - Private
}
