//
//  TrackOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

struct TrackOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [
        OptionRule("--at", value: "<t>", help: "The media time of the frame the area is on."),
        OptionRule(
            "--area",
            value: "<area>",
            help: "The area as JSON text, [x, y, w, h] in the frame at --at."
        ),
        OptionRule(
            "--to",
            value: "<t>",
            help: "Follows only the frames shown between --at and --to, which may lie on either side. "
                + "Default: the whole video."
        ),
        OptionRule(
            "--color-space",
            value: "<name>",
            help: "The colour space the media are read in, over what the file says, as a media clip's colorSpace. "
                + "Default: the file's tags."
        )
    ]
    static let positionals = [PositionalRule("<video>", help: "The video, as an absolute path.")]

    let video: String
    let time: Double
    let area: String
    let end: Double?
    let colorSpace: ColorSpace?

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.video = try arguments.requiredPositionalPath(at: 0)
        self.time = try arguments.requiredTime(of: "--at")
        self.area = try arguments.requiredValue(of: "--area")
        self.end = try arguments.time(of: "--to")
        self.colorSpace = try arguments.choice(of: "--color-space")
    }

    // MARK: - Public
    // MARK: - Private
}
