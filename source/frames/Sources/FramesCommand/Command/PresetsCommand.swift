//
//  PresetsCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Lists the presets of every pack with their descriptions, every kind or one, or prints one preset's JSON as its file
// is written.
struct PresetsCommand: Command {
    // MARK: - Property
    let name = "presets"
    let synopsis = "[<kind>] [<name>]"
    let summary = "Lists the presets of every pack by kind, each with the name a document gives it and its "
        + "description, or prints one preset's JSON."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: PresetsOptions,
        in context: CommandContext
    ) throws {
        let presets = context.presets
        let kinds = try options.kind.map { [try kind(named: $0)] } ?? PresetKind.allCases
        guard let name = options.name, let kind = kinds.first else {
            let lines = try kinds.flatMap { kind in
                try [kind.rawValue] + presets.presets(of: kind).map(line)
            }
            context.output.write(lines.map { "\($0)\n" }.joined())
            return
        }
        guard let text = try presets.text(named: name, kind: kind) else {
            throw CommandError.unknownReference(
                command: self.name,
                reference: try context.packs.unknown(.preset(kind), named: name)
            )
        }

        context.output.write(text.hasSuffix("\n") ? text : text + "\n")
    }

    // MARK: - Public
    // MARK: - Private
    private func kind(named name: String) throws -> PresetKind {
        guard let kind = PresetKind(rawValue: name) else {
            throw CommandError.unknownPresetKind(kind: name, known: PresetKind.allCases.map(\.rawValue))
        }

        return kind
    }

    // `  <pack>/<name>  <description>`, under the line of its kind, by the name a document gives it.
    private func line(_ entry: PresetEntry) -> String {
        "  \(entry.name)  \(entry.description)"
    }
}
