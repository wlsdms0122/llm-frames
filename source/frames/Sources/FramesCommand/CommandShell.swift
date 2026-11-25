//
//  CommandShell.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Runs a command line: the global options, then a command frames has or, for a command word with a `/`, a pack's tool
// (FRAMES-25 Tools). It returns the exit code: 0 on success and for help asked for, the tool's own code for a tool, 1
// with `frames: <reason>` on standard error when anything stops, and 64 with usage on standard error when no command is
// given.
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
    // The roles are built before anything runs, so a mistyped name stops the same way for a tool and for help. A
    // built-in command given `--help` anywhere among its arguments prints its help and reads none of them.
    private func run(
        _ name: String,
        arguments: [String],
        options: GlobalOptions
    ) throws -> Int32 {
        let roles = try factory.roles(for: options)
        let context = CommandContext(options: options, roles: roles, output: output, environment: environment)
        guard !name.contains("/") else {
            return try runTool(name, arguments: arguments, in: context)
        }
        guard let command = CommandTable.commands.first(where: { $0.name == name }) else {
            throw CommandError.unknownCommand(name: name)
        }
        guard !arguments.contains(CommandLineParser.help) else {
            output.write(CommandHelp(command).text)
            return 0
        }

        try run(command, arguments: arguments, in: context)

        return 0
    }

    // A tool is given its arguments unchanged, `--help` among them, so its help is its own.
    private func runTool(
        _ name: String,
        arguments: [String],
        in context: CommandContext
    ) throws -> Int32 {
        let tools = context.tools
        guard let tool = try tools.tool(named: name) else {
            throw CommandError.unknownTool(try tools.unknown(named: name))
        }

        let launcher = ToolLauncher(variables: environment.variables, framesExecutable: environment.executable)

        return try launcher.run(tool, options: context.options.written, arguments: arguments)
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
