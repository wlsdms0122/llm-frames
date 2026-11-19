//
//  ExtractOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

struct ExtractOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [
        OptionRule.from,
        OptionRule.to,
        OptionRule.step
    ]
    static let positionals = [
        PositionalRule.frameSource,
        PositionalRule(
            "<outdir>",
            help: "The directory the PNG files go in, as an absolute path. It is made when it is missing."
        )
    ]

    let source: String
    let directory: String
    let range: FrameRange

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.source = try arguments.requiredPositional(at: 0)
        self.directory = try arguments.requiredPositionalPath(at: 1)
        self.range = try arguments.frameRange()
    }

    // MARK: - Public
    // MARK: - Private
}
