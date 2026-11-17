//
//  OCROptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// `ocr <image | video> [--at <t> | --from <t> --to <t> --step <s>] [--json]`. A range is any of `--from`, `--to` and
// `--step`, which it needs, and `--at` reads one frame, so it takes none of them.
struct OCROptions: CommandOptions, Equatable {
    // MARK: - Property
    private static let rangeOptions = ["--from", "--to", "--step"]

    static let rules = [
        OptionRule("--at", value: "<t>"),
        OptionRule("--from", value: "<t>"),
        OptionRule("--to", value: "<t>"),
        OptionRule("--step", value: "<s>"),
        OptionRule("--json")
    ]
    static let placeholders = ["<image | video>"]

    let media: String
    let selection: TimeSelection
    let isMachineOutput: Bool

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.media = try arguments.requiredPositionalPath(at: 0)
        self.selection = try Self.selection(of: arguments)
        self.isMachineOutput = arguments.isSet("--json")
    }

    // MARK: - Public
    // MARK: - Private
    private static func selection(of arguments: ScannedArguments) throws -> TimeSelection {
        let given = rangeOptions.filter { arguments.value(of: $0) != nil }
        if let time = try arguments.time(of: "--at") {
            if let option = given.first {
                throw CommandError.exclusiveOptions(command: arguments.command, option: "--at", other: option)
            }

            return .at(time)
        }
        guard !given.isEmpty else { return .start }

        return .range(FrameRange(
            from: try arguments.time(of: "--from"),
            to: try arguments.time(of: "--to"),
            step: try arguments.requiredTime(of: "--step")
        ))
    }
}
