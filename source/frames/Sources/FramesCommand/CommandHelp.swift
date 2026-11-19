//
//  CommandHelp.swift
//  FramesCommand
//
//  Created by JSilver on 11/19/26.
//

// What `frames <command> --help` prints: the command's line of the usage, what it does, and each of its positional
// arguments and options with what it takes.
struct CommandHelp: Sendable {
    // MARK: - Property
    let text: String

    // MARK: - Initializer
    init<Described: Command>(_ command: Described) {
        let line = ["frames", command.name, command.synopsis].filter { !$0.isEmpty }.joined(separator: " ")
        let rows = Described.Options.positionals.map(HelpRow.init) + Described.Options.rules.map(HelpRow.init)
        let table = rows.isEmpty ? "" : "\n" + HelpTable(rows: rows).text

        self.text = "\(line)\n\n\(command.summary)\n" + table
    }

    // MARK: - Public
    // MARK: - Private
}
