//
//  LoudnessOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/21/26.
//

struct LoudnessOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [
        OptionRule(
            "--from",
            value: "<t>",
            help: "Where the range measured starts: media time for a medium, sequence time for a document. Default: 0."
        ),
        OptionRule(
            "--to",
            value: "<t>",
            help: "Where the range measured stops, after --from and at most the end of the sound. Default: the end."
        ),
        OptionRule.arguments,
        OptionRule.json
    ]
    static let positionals = [
        PositionalRule(
            "<media | document.json>",
            help: "A medium as an absolute path, or a document: a .json file, a pack template <pack>/<name>, "
                + "or - for standard input."
        )
    ]

    let source: String
    let from: Double?
    let to: Double?
    let arguments: String?
    let isMachineOutput: Bool

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.source = try arguments.requiredPositional(at: 0)
        self.from = try arguments.time(of: "--from")
        self.to = try arguments.time(of: "--to")
        self.arguments = try arguments.path(of: "--args")
        self.isMachineOutput = arguments.isSet("--json")
    }

    // MARK: - Public
    // MARK: - Private
}
