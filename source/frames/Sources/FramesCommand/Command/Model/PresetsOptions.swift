//
//  PresetsOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// `presets [<kind>] [<name>]`
struct PresetsOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules: [OptionRule] = []
    static let placeholders = ["<kind>", "<name>"]

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
