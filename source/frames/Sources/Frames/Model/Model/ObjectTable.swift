//
//  ObjectTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct ObjectTable: Equatable, Sendable {
    // MARK: - Property
    let kind: String
    let rules: [KeyRule]
    let groups: [KeyGroup]

    var keys: [String] {
        rules.map(\.name)
    }

    // MARK: - Initializer
    init(
        kind: String,
        rules: [KeyRule],
        groups: [KeyGroup] = []
    ) {
        self.kind = kind
        self.rules = rules
        self.groups = groups
    }

    // MARK: - Public
    func rule(named name: String) -> KeyRule? {
        rules.first { $0.name == name }
    }

    // MARK: - Private
}
