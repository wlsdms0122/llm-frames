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
        OptionRule.page,
        OptionRule(
            "-o",
            value: "<out>",
            help: "The file written, as an absolute path. Its extension picks the format: .jpg, .heic or .png "
                + "for a still, .m4a for audio, and .mp4, .mov or .m4v for a video, or .m4a for its sound."
        ),
        OptionRule(
            "--quality",
            value: "high|medium|low",
            help: "The quality level. Default: \(defaultQuality.rawValue)."
        ),
        OptionRule(
            "--max",
            value: "<px>",
            help: "The most pixels the longer side of a source with pixels of its own has. A smaller source is not "
                + "enlarged. Default: the source's size."
        ),
        OptionRule(
            "--scale",
            value: "<s>",
            help: "The pixels per point a page of a PDF is drawn at, a number above 0. Default: 4, or the largest at "
                + "which the decoder holds the page where that is less."
        ),
        OptionRule(
            "--codec",
            value: "h264|hevc",
            help: "The video codec. Only for a video output. Default: h264 in an SDR colour space, hevc (Main 10) in "
                + "an HDR one."
        ),
        OptionRule(
            "--color-space",
            value: "<name>",
            help: "The colour space of a picture output: "
                + ColorSpace.allCases.map(\.rawValue).joined(separator: ", ")
                + ". Default: the source's, or srgb when it is outside these."
        )
    ]
    static let positionals = [PositionalRule("<in>", help: "The image, PDF, audio or video file, as an absolute path.")]

    let request: TranscodeRequest

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.request = TranscodeRequest(
            input: try arguments.requiredPositionalPath(at: 0),
            page: try arguments.page(of: "--page"),
            output: try arguments.requiredPath(of: "-o"),
            quality: try arguments.choice(of: "--quality") ?? Self.defaultQuality,
            maximumSide: try arguments.integer(of: "--max"),
            scale: try arguments.positiveNumber(of: "--scale"),
            codec: try arguments.choice(of: "--codec"),
            colorSpace: try arguments.choice(of: "--color-space")
        )
    }

    // MARK: - Public
    // MARK: - Private
}
