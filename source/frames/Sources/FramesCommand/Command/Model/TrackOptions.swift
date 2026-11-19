//
//  TrackOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

struct TrackOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [
        OptionRule("--at", value: "<t>", help: "The media time the area is found at."),
        OptionRule(
            "--area",
            value: "<area>",
            help: "The area as JSON text, [x, y, w, h] or a text form found in the frame at --at."
        ),
        OptionRule(
            "--to",
            value: "<t>",
            help: "Follows only the frames shown between --at and --to, which may lie on either side. "
                + "Default: the whole video."
        )
    ]
    static let positionals = [PositionalRule("<video>", help: "The video, as an absolute path.")]

    let video: String
    let time: Double
    let area: String
    let end: Double?

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.video = try arguments.requiredPositionalPath(at: 0)
        self.time = try arguments.requiredTime(of: "--at")
        self.area = try arguments.requiredValue(of: "--area")
        self.end = try arguments.time(of: "--to")
    }

    // MARK: - Public
    // MARK: - Private
}
