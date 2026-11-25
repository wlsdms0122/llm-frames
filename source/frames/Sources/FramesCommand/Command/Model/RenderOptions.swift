//
//  RenderOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

struct RenderOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [
        OptionRule(
            "-o",
            value: "<out.mov | out.mp4 | out.png>",
            help: "The file written, as an absolute path: a .mov master of every frame, an .mp4 delivery of "
                + "every frame alone, or a .png of one frame."
        ),
        OptionRule(
            "--at",
            value: "<t>",
            help: "The sequence time of the frame a .png holds, in [0, duration). Only with a .png. Default: 0."
        ),
        OptionRule(
            "--deliver",
            value: "<out.mp4>",
            help: "Also writes an .mp4 delivery from the same frames. Only with a .mov."
        ),
        OptionRule.arguments,
        OptionRule(
            "--report",
            value: "<report.json>",
            help: "Also writes the run's report to a .json file when the last file is closed: its time by stage, "
                + "how each medium was read and how each file was encoded."
        ),
        OptionRule(
            "--progress",
            value: "text|json|none",
            help: "How the frames drawn are written on standard error, at most once a second and for the last frame. "
                + "Default: \(defaultProgress.rawValue)."
        )
    ]
    static let defaultProgress = ProgressFormat.text
    static let positionals = [PositionalRule.document]

    let document: String
    let output: String
    let time: Double?
    let delivery: String?
    let arguments: String?
    let report: String?
    let progress: ProgressFormat

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.document = try arguments.requiredPositional(at: 0)
        self.output = try arguments.requiredPath(of: "-o")
        self.time = try arguments.time(of: "--at")
        self.delivery = try arguments.path(of: "--deliver")
        self.arguments = try arguments.path(of: "--args")
        self.report = try arguments.path(of: "--report")
        self.progress = try arguments.choice(of: "--progress") ?? Self.defaultProgress
    }

    // MARK: - Public
    // MARK: - Private
}
