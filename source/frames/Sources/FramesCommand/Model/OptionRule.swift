//
//  OptionRule.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// An option a command takes: its name, the value's placeholder as usage writes it for one that takes a value, and
// what `--help` says it takes. An option without a placeholder is a flag.
struct OptionRule: Equatable, Sendable {
    // MARK: - Property
    static let arguments = OptionRule(
        "--args",
        value: "<args.json>",
        help: "The arguments of a template, a JSON file as an absolute path."
    )
    static let json = OptionRule("--json", help: "Prints the machine output, one JSON object.")
    static let from = OptionRule("--from", value: "<t>", help: "The time of the first frame. Default: 0.")
    static let to = OptionRule(
        "--to",
        value: "<t>",
        help: "The time the frames stop before, at most the end. Default: the end."
    )
    static let step = OptionRule(
        "--step",
        value: "<s>",
        help: "The seconds between frames, at least a microsecond. Default: 1."
    )

    let name: String
    let value: String?
    let help: String

    // MARK: - Initializer
    init(
        _ name: String,
        value: String? = nil,
        help: String
    ) {
        self.name = name
        self.value = value
        self.help = help
    }

    // MARK: - Public
    // MARK: - Private
}
