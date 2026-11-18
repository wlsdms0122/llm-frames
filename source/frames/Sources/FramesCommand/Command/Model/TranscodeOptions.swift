//
//  TranscodeOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

struct TranscodeOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [
        OptionRule("-o", value: "<out>"),
        OptionRule("--quality", value: "high|medium|low"),
        OptionRule("--max", value: "<px>"),
        OptionRule("--codec", value: "h264|hevc")
    ]
    static let placeholders = ["<in>"]

    let request: TranscodeRequest

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.request = TranscodeRequest(
            input: try arguments.requiredPositionalPath(at: 0),
            output: try arguments.requiredPath(of: "-o"),
            quality: try arguments.choice(of: "--quality") ?? .medium,
            maximumSide: try arguments.integer(of: "--max"),
            codec: try arguments.choice(of: "--codec")
        )
    }

    // MARK: - Public
    // MARK: - Private
}
