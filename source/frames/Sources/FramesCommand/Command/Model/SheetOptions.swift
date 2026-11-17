//
//  SheetOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// `sheet <video | document.json> -o <out.png> [--from <t>] [--to <t>] [--step 1] [--cols 6]`
struct SheetOptions: CommandOptions, Equatable {
    // MARK: - Property
    private static let defaultColumns = 6

    static let rules = [
        OptionRule("-o", value: "<out.png>"),
        OptionRule("--from", value: "<t>"),
        OptionRule("--to", value: "<t>"),
        OptionRule("--step", value: "<s>"),
        OptionRule("--cols", value: "<n>")
    ]
    static let placeholders = ["<video | document.json>"]

    let source: String
    let output: String
    let range: FrameRange
    let columns: Int

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.source = try arguments.requiredPositional(at: 0)
        self.output = try arguments.requiredPath(of: "-o")
        self.range = try arguments.frameRange()
        self.columns = try arguments.integer(of: "--cols") ?? Self.defaultColumns
    }

    // MARK: - Public
    // MARK: - Private
}
