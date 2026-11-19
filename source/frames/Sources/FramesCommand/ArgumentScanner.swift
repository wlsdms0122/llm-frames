//
//  ArgumentScanner.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// Scans the arguments after a command's name by the options it takes and the positional arguments it has room for.
// An argument that starts with `-` is an option, except `-` alone, which names standard input.
struct ArgumentScanner: Sendable {
    // MARK: - Property
    private let command: String
    private let rules: [OptionRule]
    private let positionals: [PositionalRule]

    // MARK: - Initializer
    init(
        command: String,
        rules: [OptionRule],
        positionals: [PositionalRule]
    ) {
        self.command = command
        self.rules = rules
        self.positionals = positionals
    }

    // MARK: - Public
    func scan(_ arguments: [String]) throws -> ScannedArguments {
        var scanned: [String] = []
        var values: [String: String] = [:]
        var flags: Set<String> = []
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let argument = arguments[index]
            index += 1
            guard isOption(argument) else {
                guard scanned.count < positionals.count else {
                    throw CommandError.unexpectedArgument(command: command, argument: argument)
                }

                scanned.append(argument)
                continue
            }
            guard let rule = rules.first(where: { $0.name == argument }) else {
                throw CommandError.unknownOption(command: command, option: argument, allowed: rules.map(\.name))
            }
            guard values[argument] == nil, !flags.contains(argument) else {
                throw CommandError.repeatedOption(command: command, option: argument)
            }
            guard let placeholder = rule.value else {
                flags.insert(argument)
                continue
            }
            guard index < arguments.endIndex else {
                throw CommandError.missingValue(command: command, option: argument, placeholder: placeholder)
            }

            values[argument] = arguments[index]
            index += 1
        }

        return ScannedArguments(
            command: command,
            placeholders: positionals.map(\.placeholder),
            rules: rules,
            positionals: scanned,
            values: values,
            flags: flags
        )
    }

    // MARK: - Private
    private func isOption(_ argument: String) -> Bool {
        argument.hasPrefix("-") && argument != "-"
    }
}
