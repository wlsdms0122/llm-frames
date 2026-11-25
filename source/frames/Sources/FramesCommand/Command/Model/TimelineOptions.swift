//
//  TimelineOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

struct TimelineOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [
        OptionRule(
            "--at",
            value: "<t>",
            help: "A sequence time, inside the sequence or outside it, at which each clip's clip time and media time, "
                + "and where its box and its masks lie, are given as well. Default: none."
        ),
        OptionRule(
            "--nested",
            value: "<place>",
            help: "The place of a compound clip or template instance, as timeline prints it, whose nested sequence is "
                + "reported instead, as it is resolved there, with --at a time on its own clock. Default: none."
        ),
        OptionRule.arguments,
        OptionRule.json
    ]
    static let positionals = [PositionalRule.document]

    let document: String
    let time: Double?
    let nested: String?
    let arguments: String?
    let isMachineOutput: Bool

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.document = try arguments.requiredPositional(at: 0)
        self.time = try arguments.time(of: "--at")
        self.nested = arguments.value(of: "--nested")
        self.arguments = try arguments.path(of: "--args")
        self.isMachineOutput = arguments.isSet("--json")
    }

    // MARK: - Public
    // MARK: - Private
}
