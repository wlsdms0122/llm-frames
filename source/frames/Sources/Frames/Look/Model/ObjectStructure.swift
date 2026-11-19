//
//  ObjectStructure.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// An object value's keys in the order it is written out, the keys the merged value requires, the lists of lengths the
// merged value may not hold as all zeros (a stroke's `dash`), the groups of keys that are one leaf (a stroke's `color`
// and `gradient`), so writing one replaces the others and each is a form of that leaf, its shorthands, the plain
// value of each key that has one, which timing gives a key no layer writes, as a filter entry's `mix` is 1, and the
// rule of each static key its structure does not state, as a style's `weight`.
struct ObjectStructure: Sendable {
    // MARK: - Property
    let keys: [(name: String, structure: ValueStructure)]
    let required: [String]
    let nonZero: [String]
    let exclusive: [[String]]
    let shorthands: [ObjectShorthand]
    let plain: [String: JSONValue]
    let checks: [String: LeafCheck]

    // MARK: - Initializer
    init(
        _ keys: [(name: String, structure: ValueStructure)],
        required: [String] = [],
        nonZero: [String] = [],
        exclusive: [[String]] = [],
        shorthands: [ObjectShorthand] = [],
        plain: [String: JSONValue] = [:],
        checks: [String: LeafCheck] = [:]
    ) {
        self.keys = keys
        self.required = required
        self.nonZero = nonZero
        self.exclusive = exclusive
        self.shorthands = shorthands
        self.plain = plain
        self.checks = checks
    }

    // MARK: - Public
    func structure(of key: String) -> ValueStructure? {
        keys.first { $0.name == key }?.structure
    }

    // The keys that are one leaf with `key` in any of its groups, itself left out.
    func partners(of key: String) -> [String] {
        exclusive.filter { $0.contains(key) }.flatMap { $0.filter { $0 != key } }
    }

    // MARK: - Private
}
