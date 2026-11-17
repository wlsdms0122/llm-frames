//
//  ProbeOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// `probe <media> [--json]`
struct ProbeOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [OptionRule("--json")]
    static let placeholders = ["<media>"]

    let media: String
    let isMachineOutput: Bool

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.media = try arguments.requiredPositionalPath(at: 0)
        self.isMachineOutput = arguments.isSet("--json")
    }

    // MARK: - Public
    // MARK: - Private
}
