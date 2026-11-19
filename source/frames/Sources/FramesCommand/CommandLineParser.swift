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
            "--ocr-languages",
            value: "<tag>[,<tag>...]",
            help: "The OCR provider's recognition languages, BCP 47 tags in order of preference. "
                + "Without it the provider detects the language of each picture."
        )
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
            ocrLanguages: try values["--ocr-languages"].map(languages),
            shaper: values["--shaper"],
            tracker: values["--tracker"],
            written: Array(arguments[..<index])
        )

        return .command(name: name, arguments: rest, options: options)
    }

    // MARK: - Private
    private func languages(_ value: String) throws -> [LanguageTag] {
        guard let languages = [LanguageTag](commaSeparated: value) else {
            throw CommandError.invalidValue(
                command: nil,
                option: "--ocr-languages",
                value: value,
                expected: "BCP 47 tags separated by commas"
            )
        }

        return languages
    }
}
