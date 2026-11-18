//
//  TrackOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

struct TrackOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [
        OptionRule("--at", value: "<t>"),
        OptionRule("--area", value: "<area>"),
        OptionRule("--to", value: "<t>")
    ]
    static let placeholders = ["<video>"]

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
