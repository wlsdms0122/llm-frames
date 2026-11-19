//
//  TranscodeOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

struct TranscodeOptions: CommandOptions, Equatable {
    // MARK: - Property
    private static let defaultQuality = EncodeQuality.medium

    static let rules = [
        OptionRule(
            "-o",
            value: "<out>",
            help: "The file written, as an absolute path. Its extension picks the format: .jpg, .heic or .png "
                + "for an image, .m4a for audio, and .mp4, .mov or .m4v for a video, or .m4a for its sound."
        ),
        OptionRule(
            "--quality",
            value: "high|medium|low",
            help: "The quality level. Default: \(defaultQuality.rawValue)."
        ),
        OptionRule(
            "--max",
            value: "<px>",
            help: "The most pixels the longer side has. A smaller source is not enlarged. Default: the source's size."
        ),
        OptionRule("--codec", value: "h264|hevc", help: "The video codec. Only for a video output. Default: h264.")
    ]
    static let positionals = [PositionalRule("<in>", help: "The image, audio or video file, as an absolute path.")]

    let request: TranscodeRequest

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.request = TranscodeRequest(
            input: try arguments.requiredPositionalPath(at: 0),
            output: try arguments.requiredPath(of: "-o"),
            quality: try arguments.choice(of: "--quality") ?? Self.defaultQuality,
            maximumSide: try arguments.integer(of: "--max"),
            codec: try arguments.choice(of: "--codec")
        )
    }

    // MARK: - Public
    // MARK: - Private
}
