//
//  ObjectTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct ObjectTable: Sendable {
    // MARK: - Property
    let kind: String
    let rules: [KeyRule]
    let group: KeyGroup?

    var keys: [String] {
        rules.map(\.name)
    }

    // MARK: - Initializer
    init(
        kind: String,
        rules: [KeyRule],
        group: KeyGroup? = nil
    ) {
        self.kind = kind
        self.rules = rules
        self.group = group
    }

    // MARK: - Public
    func rule(named name: String) -> KeyRule? {
        rules.first { $0.name == name }
    }

    // MARK: - Private
}
