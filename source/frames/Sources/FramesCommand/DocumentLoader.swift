//
//  DocumentLoader.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames

// Reads the document a command is given, and the arguments file `--args` names. A JSON object whose top level has
// `resolved` is a resolved document, read as resolve wrote it, and its theme and arguments are already written in, so
// `--theme` or `--args` with it stops.
struct DocumentLoader: Sendable {
    // MARK: - Property
    private let environment: CommandEnvironment
    private let packs: PackLibrary
    private let checker = ResolvedDocumentChecker()
    private let reader = ResolvedDocumentReader()

    // MARK: - Initializer
    init(
        environment: CommandEnvironment,
        packs: PackLibrary
    ) {
        self.environment = environment
        self.packs = packs
    }

    // MARK: - Public
    // `theme` is the `--theme` name and `arguments` the `--args` path, as given.
    func input(
        of argument: String,
        theme: String?,
        arguments: String?,
        command: String
    ) throws -> DocumentInput {
        let source = try DocumentArgument(argument, command: command)
        let document = try JSONReader().read(try data(of: source, command: command))
        let file = try arguments.map(argumentFile)
        guard try checker.version(of: document, theme: theme, arguments: file) == nil else {
            return .resolved(try reader.read(document))
        }

        return .document(document, pack: source.pack, theme: theme, arguments: file)
    }

    // MARK: - Private
    private func data(
        of argument: DocumentArgument,
        command: String
    ) throws -> Data {
        switch argument {
        case let .path(path):
            return try contents(of: path)

        case let .template(pack, name):
            let reference = PackReference.pack(pack: pack, name: name)
            guard
                let file = try packs.file(of: reference, in: "templates", pathExtension: "json"),
                let data = try packs.contents(of: file)
            else {
                throw CommandError.unknownTemplate(command: command, name: "\(pack)/\(name)")
            }

            return data

        case .standardInput:
            return environment.readStandardInput()
        }
    }

    private func argumentFile(at path: String) throws -> ArgumentFile {
        ArgumentFile(name: path, value: try JSONReader(file: path).read(try contents(of: path)))
    }

    private func contents(of path: String) throws -> Data {
        guard let data = try packs.contents(of: URL(fileURLWithPath: path)) else {
            throw CommandError.missingFile(path: path)
        }

        return data
    }
}
