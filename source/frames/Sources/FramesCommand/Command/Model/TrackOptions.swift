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
        OptionRule("--at", value: "<t>", help: "The media time of the frame the target is on."),
        OptionRule(
            "--area",
            value: "<area>",
            help: "The target as an area, JSON text [x, y, w, h] in the frame at --at. It or --quad is given."
        ),
        OptionRule(
            "--quad",
            value: "<quad>",
            help: "The target as a quadrilateral, JSON text [[x, y], [x, y], [x, y], [x, y]] in the frame at --at: "
                + "its top left, top right, bottom right and bottom left corners, a corner pin's order. It is "
                + "strictly convex, and the planar tracker follows it in perspective. It or --area is given."
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
    let target: TrackTarget
    let end: Double?
    let colorSpace: ColorSpace?

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.video = try arguments.requiredPositionalPath(at: 0)
        self.time = try arguments.requiredTime(of: "--at")
        self.target = try Self.target(of: arguments)
        self.end = try arguments.time(of: "--to")
        self.colorSpace = try arguments.choice(of: "--color-space")
    }

    // MARK: - Public
    // MARK: - Private
    // The target, from exactly one of `--area` and `--quad`.
    private static func target(of arguments: ScannedArguments) throws -> TrackTarget {
        switch (arguments.value(of: "--area"), arguments.value(of: "--quad")) {
        case let (area?, nil):
            return .area(area)

        case let (nil, quad?):
            return .quad(quad)

        case (.some, .some):
            throw CommandError.exclusiveOptions(command: arguments.command, option: "--area", other: "--quad")

        case (nil, nil):
            throw CommandError.missingEitherOption(
                command: arguments.command,
                option: "--area <area>",
                other: "--quad <quad>"
            )
        }
    }
}
