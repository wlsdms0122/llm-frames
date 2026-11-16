//
//  CommandLineParser.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// Reads a command line into what it asks for. The global options come before the command, each with a value, and
// the first argument that is not one of them is the command's name, so everything after it is the command's own.
struct CommandLineParser: Sendable {
    // MARK: - Property
    static let rules = [
        OptionRule("--theme", value: "<pack/name | /abs/theme.json>"),
        OptionRule("--decoder", value: "<name>"),
        OptionRule("--renderer", value: "<name>"),
        OptionRule("--mixer", value: "<name>"),
        OptionRule("--encoder", value: "<name>"),
        OptionRule("--ocr", value: "<name>"),
        OptionRule("--shaper", value: "<name>"),
        OptionRule("--tracker", value: "<name>")
    ]

    private static let version = "--version"

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func parse(_ arguments: [String]) throws -> Invocation {
        var values: [String: String] = [:]
        var index = arguments.startIndex
        while index < arguments.endIndex, let rule = Self.rules.first(where: { $0.name == arguments[index] }) {
            guard values[rule.name] == nil else { throw CommandError.repeatedOption(command: nil, option: rule.name) }
            guard index + 1 < arguments.endIndex else {
                throw CommandError.missingValue(command: nil, option: rule.name, placeholder: rule.value ?? "")
            }

            values[rule.name] = arguments[index + 1]
            index += 2
        }
        guard index < arguments.endIndex else { return .usage }

        let name = arguments[index]
        let rest = Array(arguments[(index + 1)...])
        guard name != Self.version else {
            guard rest.isEmpty else { throw CommandError.argumentsAfterVersion(arguments: rest) }

            return .version
        }
        guard !name.hasPrefix("-") || name == "-" else {
            throw CommandError.unknownOption(
                command: nil,
                option: name,
                allowed: Self.rules.map(\.name) + [Self.version]
            )
        }

        let options = GlobalOptions(
            theme: values["--theme"],
            decoder: values["--decoder"],
            renderer: values["--renderer"],
            mixer: values["--mixer"],
            encoder: values["--encoder"],
            ocr: values["--ocr"],
            shaper: values["--shaper"],
            tracker: values["--tracker"],
            written: Array(arguments[..<index])
        )

        return .command(name: name, arguments: rest, options: options)
    }

    // MARK: - Private
}
