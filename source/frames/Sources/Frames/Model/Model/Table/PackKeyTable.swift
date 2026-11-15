//
//  PackKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The tables of a pack's manifest that frames reads. `[open-package]` and `[package]` belong to open-package, so
// frames checks only the keys it reads in them and leaves the rest to open-package. `[frames]` is frames' own, so its
// keys are fixed.
enum PackKeyTable {
    static let manifestKind = "manifest"
    static let openPackage = ObjectTable(
        kind: manifestKind,
        rules: [
            KeyRule("version", .text, isRequired: true)
        ]
    )
    static let package = ObjectTable(
        kind: manifestKind,
        rules: [
            KeyRule("name", .text, isRequired: true),
            KeyRule("version", .text, isRequired: true),
            KeyRule("description", .text)
        ]
    )
    static let frames = ObjectTable(
        kind: manifestKind,
        rules: [
            KeyRule("engine", .text, isRequired: true)
        ]
    )
}
