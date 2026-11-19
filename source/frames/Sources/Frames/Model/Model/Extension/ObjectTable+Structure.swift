//
//  ObjectTable+Structure.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The key check's table of a look object, read from its structure. A member's kind is its key. No key is required here:
// the keys a structure requires are required of the merged value, which resolve checks, so a layer may write one leaf
// of a value below it. Each group of keys that are one leaf is an optional exclusive group.
extension ObjectTable {
    // MARK: - Property
    // MARK: - Initializer
    init(
        structure: ObjectStructure,
        kind: String,
        checksDomains: Bool = true
    ) {
        self.init(structure: structure, kind: kind, isWritten: false, checksDomains: checksDomains)
    }

    // A look object as a layer writes it over the one below, as a theme's text style is: each look object it holds is
    // written as `ValueType(written:kind:)` gives.
    init(
        written structure: ObjectStructure,
        kind: String
    ) {
        self.init(structure: structure, kind: kind, isWritten: true, checksDomains: true)
    }

    // A list the object holds not all zeros is a dash pattern, and a key with a check takes the type that applies it.
    private init(
        structure: ObjectStructure,
        kind: String,
        isWritten: Bool,
        checksDomains: Bool
    ) {
        self.init(
            kind: kind,
            rules: structure.keys.map { key in
                let type = if let check = structure.checks[key.name] {
                    ValueType(check: check)
                } else if structure.nonZero.contains(key.name) {
                    ValueType.dash(isKeyframed: false)
                } else if isWritten {
                    ValueType(written: key.structure, kind: key.name)
                } else {
                    ValueType(structure: key.structure, kind: key.name, checksDomains: checksDomains)
                }
                return KeyRule(key.name, type)
            },
            groups: structure.exclusive.map { KeyGroup(keys: $0, isExclusive: true, isOptional: true) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
