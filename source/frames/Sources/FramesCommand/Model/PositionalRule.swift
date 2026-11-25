//
//  PositionalRule.swift
//  FramesCommand
//
//  Created by JSilver on 11/19/26.
//

// A positional argument a command takes: its placeholder as usage writes it, and what `--help` says it takes.
struct PositionalRule: Equatable, Sendable {
    // MARK: - Property
    static let document = PositionalRule(
        "<document.json>",
        help: "A document, a template or a resolved document: an absolute path, a pack template <pack>/<name>, "
            + "or - for standard input."
    )
    static let frameSource = PositionalRule(
        "<video | image sequence | document.json>",
        help: "A video as an absolute path, an image sequence as the absolute path of its directory, or a "
            + "document: a .json file, a pack template <pack>/<name>, or - for standard input."
    )

    let placeholder: String
    let help: String

    // MARK: - Initializer
    init(
        _ placeholder: String,
        help: String
    ) {
        self.placeholder = placeholder
        self.help = help
    }

    // MARK: - Public
    // MARK: - Private
}
