//
//  KindTable.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The objects of several kinds one place takes, each saying which it is with the value of its `kind` and taking the
// keys of that kind's table. `kind` is what a message calls such an object before its kind is known.
struct KindTable: Equatable, Sendable {
    // MARK: - Property
    let kind: String
    let tables: [String: ObjectTable]

    // The values `kind` takes, in the order a message lists them.
    var names: [String] {
        tables.keys.sorted()
    }

    // MARK: - Initializer
    init(
        kind: String,
        tables: [String: ObjectTable]
    ) {
        self.kind = kind
        self.tables = tables
    }

    // MARK: - Public
    // MARK: - Private
}
