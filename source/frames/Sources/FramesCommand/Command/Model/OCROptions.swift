//
//  OCROptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

struct OCROptions: CommandOptions, Equatable {
    // MARK: - Property
    private static let rangeOptions = ["--from", "--to", "--step"]

    static let rules = [
        OptionRule(
            "--at",
            value: "<t>",
            help: "The media time a video is read at, in [0, duration). Default: 0."
        ),
        OptionRule.from,
        OptionRule.to,
        OptionRule(
            "--step",
            value: "<s>",
            help: "The seconds between the frames of a range, at least a microsecond. A range needs it."
        ),
        OptionRule(
            "--languages",
            value: "<tag>[,<tag>...]",
            help: "The recognition languages, BCP 47 tags in order of preference. Default: the global --ocr-languages."
        ),
        OptionRule.json
    ]
    static let positionals = [
        PositionalRule(
            "<image | video>",
            help: "An image, read whole, or a video, read at --at or over a range, as an absolute path."
        )
    ]

    let media: String
    let selection: TimeSelection
    let languages: [LanguageTag]?
    let isMachineOutput: Bool

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.media = try arguments.requiredPositionalPath(at: 0)
        self.selection = try Self.selection(of: arguments)
        self.languages = try arguments.languages(of: "--languages")
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
