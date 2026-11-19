//
//  ObjectStructure.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// An object value's keys in the order it is written out, the keys the merged value requires, the groups of keys that
// are one leaf (a stroke's `color` and `gradient`), so writing one replaces the others, and its shorthands.
struct ObjectStructure: Sendable {
    // MARK: - Property
    let keys: [(name: String, structure: ValueStructure)]
    let required: [String]
    let exclusive: [[String]]
    let shorthands: [ObjectShorthand]

    // MARK: - Initializer
    init(
        _ keys: [(name: String, structure: ValueStructure)],
        required: [String] = [],
        exclusive: [[String]] = [],
        shorthands: [ObjectShorthand] = []
    ) {
        self.keys = keys
        self.required = required
        self.exclusive = exclusive
        self.shorthands = shorthands
    }

    // MARK: - Public
    func structure(of key: String) -> ValueStructure? {
        keys.first { $0.name == key }?.structure
    }

    // The keys that are one leaf with `key`, itself left out.
    func partners(of key: String) -> [String] {
        exclusive.first { $0.contains(key) }?.filter { $0 != key } ?? []
    }

    // MARK: - Private
}
