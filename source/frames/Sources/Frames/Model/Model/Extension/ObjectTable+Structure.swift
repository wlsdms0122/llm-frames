//
//  ObjectTable+Structure.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The key check's table of a look object, read from its structure. A member's kind is its key. No key is required here:
// the keys a structure requires are required of the merged value, which resolve checks, so a layer may write one leaf
// of a value below it. Keys that are one leaf are an optional exclusive group; an object of several such groups, as a
// mask's, has a table of its own.
extension ObjectTable {
    // MARK: - Property
    // MARK: - Initializer
    // A list the object holds not all zeros is a dash pattern.
    init(
        structure: ObjectStructure,
        kind: String,
        checksDomains: Bool = true
    ) {
        self.init(
            kind: kind,
            rules: structure.keys.map { key in
                let type = structure.nonZero.contains(key.name)
                    ? ValueType.dash(isKeyframed: false)
                    : ValueType(structure: key.structure, kind: key.name, checksDomains: checksDomains)
                return KeyRule(key.name, type)
            },
            group: structure.exclusive.count == 1
                ? KeyGroup(keys: structure.exclusive[0], isExclusive: true, isOptional: true)
                : nil
        )
    }

    // MARK: - Public
    // MARK: - Private
}
