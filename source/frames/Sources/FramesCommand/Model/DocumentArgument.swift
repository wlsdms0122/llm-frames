//
//  DocumentArgument.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// How a document argument names its document: an absolute path, a pack template as `<pack>/<name>`, or `-` for
// standard input. Paths are absolute, so any other spelling names nothing.
enum DocumentArgument: Equatable, Sendable {
    case path(String)
    case template(pack: String, name: String)
    case standardInput

    // MARK: - Property
    // The pack a template is read from.
    var pack: String? {
        guard case let .template(pack, _) = self else { return nil }

        return pack
    }

    // The document as a message names it: its path, `<pack>/<name>`, or `standard input`.
    var name: String {
        switch self {
        case let .path(path):
            path

        case let .template(pack, name):
            "\(pack)/\(name)"

        case .standardInput:
            "standard input"
        }
    }

    // MARK: - Initializer
    init(
        _ argument: String,
        command: String
    ) throws {
        guard argument != "-" else {
            self = .standardInput
            return
        }

        switch PackReference(argument) {
        case let .path(path):
            self = .path(path)

        case let .pack(pack, name):
            self = .template(pack: pack, name: name)

        case nil:
            throw CommandError.unknownDocument(command: command, argument: argument)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
