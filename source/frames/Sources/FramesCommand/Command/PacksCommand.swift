//
//  PacksCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames

// Lists the shipped and installed packs with what their `pack.json` says, or what one pack holds, by kind, each thing
// by the name a document or a command gives it, under each preset and template the parameters it publishes, and each
// tool with its description.
struct PacksCommand: Command {
    // MARK: - Property
    let name = "packs"
    let synopsis = "[<pack>]"
    let summary = "Lists the packs, the one that ships with frames and the installed ones, or what one pack holds, "
        + "with the parameters each preset and template publishes and the tools it holds."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: PacksOptions,
        in context: CommandContext
    ) throws {
        let packs = context.packs
        guard let name = options.pack else {
            context.output.write(try packs.packs().map { line(of: $0) + "\n" }.joined())
            return
        }
        guard let pack = try packs.pack(named: name) else { throw CommandError.unknownPack(name: name) }

        let presets = try PresetKind.allCases.flatMap { kind in
            try context.presets.presets(of: kind, in: pack).flatMap { entry in
                ["\(kind.rawValue)  \(entry.name)  \(entry.description)"] + entry.parameters.map(line(of:))
            }
        }
        let library = context.library
        let files = try PackFolder.all.flatMap { folder in
            try packs.names(in: folder.folder, of: pack, pathExtension: folder.pathExtension).flatMap { file in
                let name = folder.isNamed ? "\(pack.name)/\(file)" : file
                let parameters = folder == .template ? try library.templateParameters(named: name) ?? [] : []

                return ["\(folder.kind)  \(name)"] + parameters.map(line(of:))
            }
        }

        let tools = try context.tools.tools(in: pack).map { "tool  \($0.name)  \($0.description)" }

        context.output.write(([line(of: pack)] + presets + files + tools).map { $0 + "\n" }.joined())
    }

    // MARK: - Public
    // MARK: - Private
    // `<pack>  <name>  <version>  <description>`, the pack by its directory, and `-` for what its `pack.json` leaves
    // out.
    private func line(of pack: Pack) -> String {
        let manifest = pack.manifest

        return [pack.name, manifest.name ?? "-", manifest.version ?? "-", manifest.description ?? "-"]
            .joined(separator: "  ")
    }

    // `  <name>  <type>  <default>  <description>`, indented under what publishes it, the default as JSON on one line
    // and `-` for a template parameter without one.
    private func line(of parameter: Parameter) -> String {
        let defaultValue = parameter.defaultValue.map { value in
            JSONWriter().write(value)
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: " ")
        }

        return "  " + [parameter.name, parameter.type.rawValue, defaultValue ?? "-", parameter.description]
            .joined(separator: "  ")
    }
}
