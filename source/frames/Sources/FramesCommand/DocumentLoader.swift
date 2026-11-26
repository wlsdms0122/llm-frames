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
    // The bytes JSON reads as white space.
    private static let whiteSpace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]

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
        let document = try read(try data(of: source, command: command), of: source)
        let file = try arguments.map(argumentFile)
        guard try checker.version(of: document, theme: theme, arguments: file) == nil else {
            return .resolved(try reader.read(document))
        }

        return .document(document, pack: source.pack, theme: theme, arguments: file)
    }

    // MARK: - Private
    // A document that is not JSON stops naming the document, and one whose first character other than white space is
    // not `{` is also said to be no frames document.
    private func read(
        _ data: Data,
        of source: DocumentArgument
    ) throws -> JSONValue {
        do {
            return try JSONReader(file: source.name).read(data)
        } catch let error as JSONError {
            let first = data.first { !Self.whiteSpace.contains($0) }
            guard first == UInt8(ascii: "{") else { throw CommandError.notDocument(error) }

            throw error
        }
    }

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
                throw CommandError.unknownReference(
                    command: command,
                    reference: try packs.unknown(.template, named: "\(pack)/\(name)")
                )
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
