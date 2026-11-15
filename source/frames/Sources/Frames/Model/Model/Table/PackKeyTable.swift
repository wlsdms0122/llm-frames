//
//  PackKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The tables of a pack's manifest that frames reads. `[open-package]` belongs to open-package, so frames reads only
// the name in it, and `[frames]` is frames' own, so its keys are fixed.
enum PackKeyTable {
    static let manifestKind = "manifest"
    static let openPackage = "open-package"
    static let frames = ObjectTable(
        kind: manifestKind,
        rules: [
            KeyRule("engine", .name, isRequired: true)
        ]
    )
}
