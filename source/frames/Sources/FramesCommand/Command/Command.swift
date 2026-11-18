//
//  Command.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

protocol Command: Sendable {
    associatedtype Options: CommandOptions

    var name: String { get }

    func run(
        _ options: Options,
        in context: CommandContext
    ) throws
}
