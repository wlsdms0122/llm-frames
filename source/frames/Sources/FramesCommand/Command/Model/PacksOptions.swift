//
//  PacksOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

struct PacksOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules: [OptionRule] = []
    static let positionals = [
        PositionalRule(
            "<pack>",
            help: "The pack whose themes, presets, templates, files and tools are listed."
        )
    ]

    let pack: String?

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.pack = arguments.positional(at: 0)
    }

    // MARK: - Public
    // MARK: - Private
}
