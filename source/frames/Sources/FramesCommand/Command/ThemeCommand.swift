//
//  ThemeCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Prints the base theme, which is also the list of every key a theme can hold.
struct ThemeCommand: Command {
    // MARK: - Property
    let name = "theme"
    let synopsis = ""
    let summary = "Prints the base theme, which is also the list of every group a theme holds."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: ThemeOptions,
        in context: CommandContext
    ) throws {
        context.output.write(BaseTheme.text + "\n")
    }

    // MARK: - Public
    // MARK: - Private
}
