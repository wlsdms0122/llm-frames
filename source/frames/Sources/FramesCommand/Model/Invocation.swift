//
//  Invocation.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// What a command line asks for: usage when it names no command, the version, or a command with the arguments after
// its name.
enum Invocation: Equatable, Sendable {
    case usage
    case version
    case command(name: String, arguments: [String], options: GlobalOptions)
}
