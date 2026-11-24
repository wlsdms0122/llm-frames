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
        OptionRule.arguments
    ]
    static let positionals = [PositionalRule.document]

    let document: String
    let output: String
    let time: Double?
    let delivery: String?
    let arguments: String?

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.document = try arguments.requiredPositional(at: 0)
        self.output = try arguments.requiredPath(of: "-o")
        self.time = try arguments.time(of: "--at")
        self.delivery = try arguments.path(of: "--deliver")
        self.arguments = try arguments.path(of: "--args")
    }

    // MARK: - Public
    // MARK: - Private
}
