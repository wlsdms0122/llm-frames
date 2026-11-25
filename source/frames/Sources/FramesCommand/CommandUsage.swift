//
//  CommandUsage.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// The usage: the global options and every command's line. Each line is the command's name and its synopsis, so it
// reads the same as the first line of the command's help.
struct CommandUsage: Sendable {
    // MARK: - Property
    var text: String {
        let options = CommandLineParser.rules.map { "[\(HelpRow($0).term)]" } + ["<command> ..."]
        let width = (CommandTable.commands.map(\.name.count).max() ?? 0) + 1
        let lines = CommandTable.commands.map { command in
            command.synopsis.isEmpty
                ? command.name
                : command.name + String(repeating: " ", count: width - command.name.count) + command.synopsis
        }

        return (["frames " + options.joined(separator: " "), ""] + lines).map { "\($0)\n" }.joined()
    }

    // What `frames --help` prints: the usage, then each global option with what it takes.
    var help: String {
        text
            + "\nGlobal options:\n"
            + HelpTable(rows: CommandLineParser.rules.map(HelpRow.init)).text
            + "\nframes <command> --help describes a command, its arguments and its options.\n"
            + "frames <pack>/<name> ... runs a tool of a pack, and frames packs <pack> lists the tools it holds.\n"
    }

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // MARK: - Private
}
