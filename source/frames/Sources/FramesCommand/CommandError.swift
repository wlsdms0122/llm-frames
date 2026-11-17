//
//  CommandError.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Why a command line stops before or around what the library does. A message about a command's arguments names the
// command, and one about the global options or the command line as a whole names the option.
enum CommandError: Error, Equatable, CustomStringConvertible, Sendable {
    case unknownOption(command: String?, option: String, allowed: [String])
    case missingValue(command: String?, option: String, placeholder: String)
    case repeatedOption(command: String?, option: String)
    case missingOption(command: String, option: String, placeholder: String?)
    case missingArgument(command: String, placeholder: String)
    case unexpectedArgument(command: String, argument: String)
    case relativePath(command: String, option: String, path: String)
    case invalidValue(command: String, option: String, value: String, expected: String)
    case exclusiveOptions(command: String, option: String, other: String)
    case argumentsAfterVersion(arguments: [String])
    case unknownRole(option: String, role: String, name: String, known: [String])
    case unknownCommand(name: String)
    case unstartableExtension(path: String, reason: String)
    case unknownDocument(command: String, argument: String)
    case unknownTemplate(command: String, name: String)
    case missingFile(path: String)
    case unwritableFile(path: String)
    case resolvedExtension(path: String)
    case unknownPresetKind(kind: String, known: [String])
    case unknownPreset(kind: String, name: String)
    case unknownPack(name: String)
    case missingLabelFace(name: String, file: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .unknownOption(command, option, allowed):
            allowed.isEmpty
                ? "\(prefix(command))unknown option \(quoted(option)). It takes no options"
                : "\(prefix(command))unknown option \(quoted(option)). Allowed: \(allowed.joined(separator: ", "))"

        case let .missingValue(command, option, placeholder):
            "\(prefix(command))\(option) takes a value, \(placeholder)"

        case let .repeatedOption(command, option):
            "\(prefix(command))\(option) is given more than once"

        case let .missingOption(command, option, placeholder):
            "\(command): missing \([option, placeholder].compactMap(\.self).joined(separator: " "))"

        case let .missingArgument(command, placeholder):
            "\(command): missing \(placeholder)"

        case let .unexpectedArgument(command, argument):
            "\(command): unexpected argument \(quoted(argument))"

        case let .relativePath(command, option, path):
            "\(command): \(option) \(quoted(path)) is not an absolute path, and paths are absolute"

        case let .invalidValue(command, option, value, expected):
            "\(command): \(option) \(quoted(value)) is not \(expected)"

        case let .exclusiveOptions(command, option, other):
            "\(command): \(option) and \(other) are not given together"

        case let .argumentsAfterVersion(arguments):
            "--version takes no arguments, found \(arguments.map(quoted).joined(separator: ", "))"

        case let .unknownRole(option, role, name, known):
            "\(option): unknown \(role) \(quoted(name)). Known: \(known.joined(separator: ", "))"

        case let .unknownCommand(name):
            "unknown command \(quoted(name))"

        case let .unstartableExtension(path, reason):
            "\(path): the extension cannot be started: \(reason)"

        case let .unknownDocument(command, argument):
            "\(command): the document \(quoted(argument)) is not an absolute path, <pack>/<name> or -, "
                + "and paths are absolute"

        case let .unknownTemplate(command, name):
            "\(command): unknown template \(quoted(name))"

        case let .missingFile(path):
            "\(path): the file is not there"

        case let .unwritableFile(path):
            "\(path): the file cannot be written"

        case let .resolvedExtension(path):
            "resolve: \(quoted(path)): a resolved document is written to a .json file"

        case let .unknownPresetKind(kind, known):
            "presets: unknown kind \(quoted(kind)). Known: \(known.joined(separator: ", "))"

        case let .unknownPreset(kind, name):
            "presets: unknown \(kind) preset \(quoted(name))"
                + ". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"

        case let .unknownPack(name):
            "packs: unknown pack \(quoted(name))"

        case let .missingLabelFace(name, file):
            "\(quoted(file)): the file has no face \(quoted(name)), which time labels are set in"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func prefix(_ command: String?) -> String {
        command.map { "\($0): " } ?? ""
    }

    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }
}
