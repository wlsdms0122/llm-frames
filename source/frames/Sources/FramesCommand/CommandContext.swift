//
//  CommandContext.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames

// What a command runs with: the global options, the roles they pick, where packs and presets are found, and where
// the command writes.
struct CommandContext: Sendable {
    // MARK: - Property
    // The face of the time labels of `still` and `sheet`, in a font file macOS installs.
    private static let labelFile = "/System/Library/Fonts/HelveticaNeue.ttc"
    private static let labelFaceName = "HelveticaNeue-Medium"

    let options: GlobalOptions
    let roles: Roles
    let output: CommandOutput
    private let environment: CommandEnvironment

    var packs: PackLibrary {
        PackLibrary(environment: environment.variables, shipped: environment.shippedPacks)
    }

    var presets: PresetLibrary {
        PresetLibrary(packs: packs)
    }

    var library: ReferenceLibrary {
        ReferenceLibrary(packs: packs, mediaFacts: roles.decoder)
    }

    var exporter: FrameExporter {
        FrameExporter(
            decoder: roles.decoder,
            renderer: roles.renderer,
            encoder: roles.encoder,
            mediaFacts: roles.decoder,
            shaper: roles.shaper
        )
    }

    // MARK: - Initializer
    init(
        options: GlobalOptions,
        roles: Roles,
        output: CommandOutput,
        environment: CommandEnvironment
    ) {
        self.options = options
        self.roles = roles
        self.output = output
        self.environment = environment
    }

    // MARK: - Public
    // The planner of a document read from `pack`, nil for one outside every pack.
    func planner(in pack: String?) -> DocumentPlanner {
        DocumentPlanner(
            mediaFacts: roles.decoder,
            presets: presets,
            shaper: roles.shaper,
            packs: packs,
            pack: pack
        )
    }

    func labelFace() throws -> FontFace {
        guard let face = roles.shaper.face(named: Self.labelFaceName, in: Self.labelFile) else {
            throw CommandError.missingLabelFace(name: Self.labelFaceName, file: Self.labelFile)
        }

        return face
    }

    // The document a command is given as `argument`, with `--theme` and the `--args` file at `arguments`.
    func document(
        _ argument: String,
        arguments: String?,
        command: String
    ) throws -> DocumentInput {
        try DocumentLoader(environment: environment, packs: packs)
            .input(of: argument, theme: options.theme, arguments: arguments, command: command)
    }

    // The frames of `sheet` and `extract` that `argument` names, a document used resolved.
    func frameSource(
        _ argument: FrameSourceArgument,
        command: String
    ) throws -> FrameSource {
        switch argument {
        case let .document(document):
            .document(try self.document(document, arguments: nil, command: command).resolved(in: self))

        case let .video(path):
            .video(path: path)
        }
    }

    func write(
        _ text: String,
        to path: String
    ) throws {
        do {
            try Data(text.utf8).write(to: URL(fileURLWithPath: path))
        } catch {
            throw CommandError.unwritableFile(path: path)
        }
    }

    // One line for a file the command wrote: its path and its size.
    func reportWritten(_ path: String) throws {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        guard let bytes = (attributes?[.size] as? NSNumber)?.int64Value else {
            throw CommandError.missingFile(path: path)
        }

        output.write("\(path)  \(FileSize(bytes: bytes))\n")
    }

    // MARK: - Private
}
