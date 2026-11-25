//
//  SheetOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

struct SheetOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let defaultColumns = 6

    static let rules = [
        OptionRule("-o", value: "<out.png>", help: "The PNG written, as an absolute path."),
        OptionRule.fps,
        OptionRule.from,
        OptionRule.to,
        OptionRule.step,
        OptionRule(
            "--cols",
            value: "<n>",
            help: "The number of columns, or one per frame when there are fewer frames. Default: \(defaultColumns)."
        )
    ]
    static let positionals = [PositionalRule.frameSource]

    let source: String
    let fps: Double?
    let output: String
    let range: FrameRange
    let columns: Int

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.source = try arguments.requiredPositional(at: 0)
        self.fps = try arguments.positiveNumber(of: "--fps")
        self.output = try arguments.requiredPath(of: "-o")
        self.range = try arguments.frameRange()
        self.columns = try arguments.integer(of: "--cols") ?? Self.defaultColumns
    }

    // MARK: - Public
    // MARK: - Private
}
