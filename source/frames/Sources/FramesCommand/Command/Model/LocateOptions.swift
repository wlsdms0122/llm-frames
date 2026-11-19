//
//  LocateOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

struct LocateOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [
        OptionRule("--at", value: "<t>", help: "The sequence time, in [0, duration)."),
        OptionRule("--point", value: "<x,y>", help: "The point of the output, in its pixels."),
        OptionRule.arguments
    ]
    static let positionals = [PositionalRule.document]

    let document: String
    let time: Double
    let point: Point
    let arguments: String?

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.document = try arguments.requiredPositional(at: 0)
        self.time = try arguments.requiredTime(of: "--at")
        self.point = try arguments.requiredPoint(of: "--point")
        self.arguments = try arguments.path(of: "--args")
    }

    // MARK: - Public
    // MARK: - Private
}
