//
//  PacksOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// `packs [<pack>]`
struct PacksOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules: [OptionRule] = []
    static let placeholders = ["<pack>"]

    let pack: String?

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.pack = arguments.positional(at: 0)
    }

    // MARK: - Public
    // MARK: - Private
}
