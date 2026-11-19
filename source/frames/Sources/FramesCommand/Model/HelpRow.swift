//
//  HelpRow.swift
//  FramesCommand
//
//  Created by JSilver on 11/19/26.
//

// One argument or option as help lists it: what is written on the command line, and what it takes.
struct HelpRow: Equatable, Sendable {
    // MARK: - Property
    let term: String
    let description: String

    // MARK: - Initializer
    init(
        term: String,
        description: String
    ) {
        self.term = term
        self.description = description
    }

    init(_ rule: OptionRule) {
        self.init(term: [rule.name, rule.value].compactMap(\.self).joined(separator: " "), description: rule.help)
    }

    init(_ rule: PositionalRule) {
        self.init(term: rule.placeholder, description: rule.help)
    }

    // MARK: - Public
    // MARK: - Private
}
