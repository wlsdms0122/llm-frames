//
//  OCRCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Prints the lines the OCR provider recognises in an image or in video frames: the text for people, or with `--json`
// the machine output.
struct OCRCommand: Command {
    // MARK: - Property
    let name = "ocr"

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: OCROptions,
        in context: CommandContext
    ) throws {
        let roles = context.roles
        let reporter = OCRReporter(mediaFacts: roles.decoder, ocr: roles.ocr)
        let report = try reporter.report(of: options.media, at: options.selection)

        context.output.write(options.isMachineOutput ? JSONWriter().write(report.machineOutput) : report.text + "\n")
    }

    // MARK: - Public
    // MARK: - Private
}
