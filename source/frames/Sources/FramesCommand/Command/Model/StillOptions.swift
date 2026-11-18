//
//  StillOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

struct StillOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [
        OptionRule("--at", value: "<t>[,<t>...]"),
        OptionRule("-o", value: "<out.png>"),
        OptionRule("--args", value: "<args.json>")
    ]
    static let placeholders = ["<document.json>"]

    let document: String
    let times: [Double]
    let output: String
    let arguments: String?

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.document = try arguments.requiredPositional(at: 0)
        self.times = try arguments.requiredTimes(of: "--at")
        self.output = try arguments.requiredPath(of: "-o")
        self.arguments = try arguments.path(of: "--args")
    }

    // MARK: - Public
    // MARK: - Private
}
