//
//  Command.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

protocol Command: Sendable {
    associatedtype Options: CommandOptions

    var name: String { get }
    // The command's line of the usage after its name, which its help repeats.
    var synopsis: String { get }
    // What the command does, as its help says it.
    var summary: String { get }

    func run(
        _ options: Options,
        in context: CommandContext
    ) throws
}
