//
//  OCRCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Prints the lines the OCR provider recognises in an image or in video frames, in the recognition languages of
// `--languages` in place of the global `--ocr-languages`: the text for people, or with `--json` the machine output.
struct OCRCommand: Command {
    // MARK: - Property
    let name = "ocr"
    let synopsis = "<image | video> [--at <t> | --from <t> --to <t> --step <s>] [--languages <tag>[,<tag>...]] [--json]"
    let summary = "Prints the picture's size, then each recognised line as [x, y, w, h] and its text in media "
        + "pixels, in the order a text area's nth counts them. Over a range it does this for each frame, "
        + "under its media time."

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
            languages: options.languages ?? context.options.ocrLanguages
        )
        let report = try reporter.report(of: options.media, at: options.selection)

        context.output.write(options.isMachineOutput ? JSONWriter().write(report.machineOutput) : report.text + "\n")
    }

    // MARK: - Public
    // MARK: - Private
}
