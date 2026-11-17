//
//  Command.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// A command frames has: its name, the options it is given, and what it does with them.
protocol Command: Sendable {
    associatedtype Options: CommandOptions

    var name: String { get }

    func run(
        _ options: Options,
        in context: CommandContext
    ) throws
}
