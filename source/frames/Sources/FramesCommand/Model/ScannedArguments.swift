//
//  ScannedArguments.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// A command's arguments sorted into its positional arguments, the values of its options and the flags it was given,
// with the rules they were scanned by, so what is missing is named as usage writes it.
struct ScannedArguments: Equatable, Sendable {
    // MARK: - Property
    let command: String
    private let placeholders: [String]
    private let rules: [OptionRule]
    private let positionals: [String]
    private let values: [String: String]
    private let flags: Set<String>

    // MARK: - Initializer
    init(
        command: String,
        placeholders: [String],
        rules: [OptionRule],
        positionals: [String],
        values: [String: String],
        flags: Set<String>
    ) {
        self.command = command
        self.placeholders = placeholders
        self.rules = rules
        self.positionals = positionals
        self.values = values
        self.flags = flags
    }

    // MARK: - Public
    func positional(at index: Int) -> String? {
        positionals.indices.contains(index) ? positionals[index] : nil
    }

    func requiredPositional(at index: Int) throws -> String {
        guard let argument = positional(at: index) else {
            let placeholder = placeholders.indices.contains(index) ? placeholders[index] : "an argument"
            throw CommandError.missingArgument(command: command, placeholder: placeholder)
        }

        return argument
    }

    func value(of option: String) -> String? {
        values[option]
    }

    func requiredValue(of option: String) throws -> String {
        guard let value = values[option] else {
            let placeholder = rules.first { $0.name == option }?.value
            throw CommandError.missingOption(command: command, option: option, placeholder: placeholder)
        }

        return value
    }

    func path(of option: String) throws -> String? {
        guard values[option] != nil else { return nil }

        return try requiredPath(of: option)
    }

    // Paths are absolute, so a relative one stops rather than depend on where frames was run from.
    func requiredPath(of option: String) throws -> String {
        let path = try requiredValue(of: option)
        guard path.hasPrefix("/") else {
            throw CommandError.relativePath(command: command, option: option, path: path)
        }

        return path
    }

    func isSet(_ flag: String) -> Bool {
        flags.contains(flag)
    }

    // MARK: - Private
}
