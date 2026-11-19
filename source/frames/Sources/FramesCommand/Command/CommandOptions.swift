//
//  CommandOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// A command's parsed arguments: the options it takes and its positional arguments, in order, and the values read
// from what the scanner found.
protocol CommandOptions: Sendable {
    static var rules: [OptionRule] { get }
    static var positionals: [PositionalRule] { get }

    init(_ arguments: ScannedArguments) throws
}
