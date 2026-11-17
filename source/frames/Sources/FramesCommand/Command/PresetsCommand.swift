//
//  PresetsCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Lists the built in presets and those of every pack with their descriptions, every kind or one, or prints one
// preset's JSON as its file is written.
struct PresetsCommand: Command {
    // MARK: - Property
    let name = "presets"

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
            let lines = try kinds.flatMap { try presets.presets(of: $0) }.map(line)
            context.output.write(lines.map { "\($0)\n" }.joined())
            return
        }
        guard let text = try presets.text(named: name, kind: kind) else {
            throw CommandError.unknownPreset(kind: kind.rawValue, name: name)
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

    // `<kind>/<name>  <description>`, a pack's preset named `<pack>/<name>`.
    private func line(_ entry: PresetEntry) -> String {
        "\(entry.kind.rawValue)/\(entry.name)  \(entry.description)"
    }
}
