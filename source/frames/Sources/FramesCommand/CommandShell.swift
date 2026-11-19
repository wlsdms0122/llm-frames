//
//  CommandShell.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Runs a command line: the global options, then a command frames has or an extension on `PATH`. It returns the exit
// code: 0 on success and for help asked for, 1 with `frames: <reason>` on standard error when anything stops, and 64
// with usage on standard error when no command is given.
package struct CommandShell: Sendable {
    // MARK: - Property
    private static let usageCode: Int32 = 64

    private let environment: CommandEnvironment
    private let output: CommandOutput
    private let parser = CommandLineParser()
    private let factory = RoleFactory()
    private let usage = CommandUsage()

    // MARK: - Initializer
    package init(
        environment: CommandEnvironment,
        output: CommandOutput
    ) {
        self.environment = environment
        self.output = output
    }

    // MARK: - Public
    // `arguments` are those after the tool's own name.
    package func run(_ arguments: [String]) -> Int32 {
        do {
            switch try parser.parse(arguments) {
            case .usage:
                output.writeError(usage.text)
                return Self.usageCode

            case let .help(options):
                _ = try factory.roles(for: options)
                output.write(usage.help)
                return 0

            case .version:
                output.write(FramesVersion.current + "\n")
                return 0

            case let .command(name, arguments, options):
                return try run(name, arguments: arguments, options: options)
            }
        } catch {
            output.writeError("frames: \(error)\n")
            return 1
        }
    }

    // MARK: - Private
    // The roles are built before anything runs, so a mistyped name stops the same way for an extension and for help.
    // A built-in command given `--help` anywhere among its arguments prints its help and reads none of them.
    private func run(
        _ name: String,
        arguments: [String],
        options: GlobalOptions
    ) throws -> Int32 {
        let roles = try factory.roles(for: options)
        guard let command = CommandTable.commands.first(where: { $0.name == name }) else {
            let launcher = ExtensionLauncher(variables: environment.variables)
            guard let code = try launcher.run(name, options: options.written, arguments: arguments) else {
                throw CommandError.unknownCommand(name: name)
            }

            return code
        }
        guard !arguments.contains(CommandLineParser.help) else {
            output.write(CommandHelp(command).text)
            return 0
        }

        let context = CommandContext(options: options, roles: roles, output: output, environment: environment)
        try run(command, arguments: arguments, in: context)

        return 0
    }

    private func run<Selected: Command>(
        _ command: Selected,
        arguments: [String],
        in context: CommandContext
    ) throws {
        let scanner = ArgumentScanner(
            command: command.name,
            rules: Selected.Options.rules,
            positionals: Selected.Options.positionals
        )

        try command.run(Selected.Options(scanner.scan(arguments)), in: context)
    }
}
