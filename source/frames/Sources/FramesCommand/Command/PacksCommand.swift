//
//  PacksCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Lists the installed and shipped packs with what their `pack.json` says, or what one pack holds, by kind, each
// thing by the name a document gives it.
struct PacksCommand: Command {
    // MARK: - Property
    let name = "packs"

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
            try context.presets.presets(of: kind, in: pack).map { "\(kind.rawValue)  \($0.name)  \($0.description)" }
        }
        let files = try PackFolder.all.flatMap { folder in
            try packs.names(in: folder.folder, of: pack, pathExtension: folder.pathExtension).map { file in
                "\(folder.kind)  \(folder.isNamed ? "\(pack.name)/\(file)" : file)"
            }
        }

        context.output.write(([line(of: pack)] + presets + files).map { $0 + "\n" }.joined())
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
}
