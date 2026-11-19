//
//  PresetsOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

struct PresetsOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules: [OptionRule] = []
    static let positionals = [
        PositionalRule(
            "<kind>",
            help: "Lists one kind: \(PresetKind.allCases.map(\.rawValue).joined(separator: ", ")). Default: every kind."
        ),
        PositionalRule(
            "<name>",
            help: "Prints the JSON of the preset of that kind named <pack>/<name>, its params included."
        )
    ]

    let kind: String?
    let name: String?

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.kind = arguments.positional(at: 0)
        self.name = arguments.positional(at: 1)
    }

    // MARK: - Public
    // MARK: - Private
}
