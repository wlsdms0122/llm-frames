//
//  TimelineOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

struct TimelineOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [
        OptionRule.arguments,
        OptionRule.json
    ]
    static let positionals = [PositionalRule.document]

    let document: String
    let arguments: String?
    let isMachineOutput: Bool

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.document = try arguments.requiredPositional(at: 0)
        self.arguments = try arguments.path(of: "--args")
        self.isMachineOutput = arguments.isSet("--json")
    }

    // MARK: - Public
    // MARK: - Private
}
