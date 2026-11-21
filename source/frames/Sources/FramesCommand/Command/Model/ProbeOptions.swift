//
//  ProbeOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

struct ProbeOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [OptionRule.page, OptionRule.json]
    static let positionals = [
        PositionalRule(
            "<media>",
            help: "An image, video, audio or PDF file, or a directory of frames as an image sequence, as an absolute "
                + "path."
        )
    ]

    let media: String
    let page: Int?
    let isMachineOutput: Bool

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.media = try arguments.requiredPositionalPath(at: 0)
        self.page = try arguments.page(of: "--page")
        self.isMachineOutput = arguments.isSet("--json")
    }

    // MARK: - Public
    // MARK: - Private
}
