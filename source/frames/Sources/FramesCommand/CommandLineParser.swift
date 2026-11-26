//
//  CommandLineParser.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Reads a command line into what it asks for. The global options come before the command, each with a value, and
// the first argument that is not one of them is the command's name, so everything after it is the command's own.
struct CommandLineParser: Sendable {
    // MARK: - Property
    static let rules = [
        OptionRule(
            "--theme",
            value: "<pack/name | /abs/theme.json>",
            help: "A theme merged under every document's own theme: a pack theme or a JSON file as an absolute path."
        )
    ] + RoleFactory().rules + [
        OptionRule(
            memory,
            value: "<size>",
            help: "The run's budget of memory, as <n>MB or <n>GB of 2^20 and 2^30 bytes: what frames holds of frames, pictures and sound, by their sizes, and each open video reader at a set number of its frames. It is not a bound on what the run really uses. Default: three eighths of the machine's memory."
        )
    ]

    static let help = "--help"
    private static let memory = "--memory"
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
        guard !name.hasPrefix("-") || name == "-" || name == Self.help else {
            throw CommandError.unknownOption(
                command: nil,
                option: name,
                allowed: Self.rules.map(\.name) + [Self.version, Self.help]
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
            memory: try values[Self.memory].map(memorySize),
            written: Array(arguments[..<index])
        )
        guard name != Self.help else {
            guard rest.isEmpty else { throw CommandError.argumentsAfterHelp(arguments: rest) }

            return .help(options: options)
        }

        return .command(name: name, arguments: rest, options: options)
    }

    // MARK: - Private
    private func memorySize(_ text: String) throws -> MemorySize {
        guard let size = MemorySize(text) else {
            throw CommandError.invalidValue(
                command: nil,
                option: Self.memory,
                value: text,
                expected: "a size of at least 1MB, <n>MB or <n>GB"
            )
        }

        return size
    }
}
