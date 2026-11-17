//
//  CommandOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// A command's parsed arguments: the options it takes and the placeholders of its positional arguments, as usage
// writes them, and the values read from what the scanner found.
protocol CommandOptions: Sendable {
    static var rules: [OptionRule] { get }
    static var placeholders: [String] { get }

    init(_ arguments: ScannedArguments) throws
}
