//
//  RenderOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// `render <document.json> -o <out.mov | out.png> [--deliver <out.mp4>] [--args <args.json>]`
struct RenderOptions: CommandOptions, Equatable {
    // MARK: - Property
    static let rules = [
        OptionRule("-o", value: "<out.mov | out.png>"),
        OptionRule("--deliver", value: "<out.mp4>"),
        OptionRule("--args", value: "<args.json>")
    ]
    static let placeholders = ["<document.json>"]

    let document: String
    let output: String
    let delivery: String?
    let arguments: String?

    // MARK: - Initializer
    init(_ arguments: ScannedArguments) throws {
        self.document = try arguments.requiredPositional(at: 0)
        self.output = try arguments.requiredPath(of: "-o")
        self.delivery = try arguments.path(of: "--deliver")
        self.arguments = try arguments.path(of: "--args")
    }

    // MARK: - Public
    // MARK: - Private
}
