//
//  DocumentKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum DocumentKeyTable {
    static let theme = ValueType.oneOf([.name, .object(ThemeKeyTable.theme)])
    static let sequence = ObjectTable(
        kind: "sequence",
        rules: [
            KeyRule("kind", .literal(["sequence"]), isRequired: true),
            KeyRule("format", .object(format)),
            KeyRule("theme", theme),
            KeyRule("params", .parameters),
            KeyRule("storyline", .clips(.storyline)),
            KeyRule("clips", .clips(.sequence))
        ]
    )
    static let format = ObjectTable(
        kind: "format",
        rules: [
            KeyRule("size", .numbers(2)),
            KeyRule("fps", .positiveNumber),
            KeyRule("background", .color),
            KeyRule("inset", .numbers(4)),
            KeyRule("conform", .literal(VocabularyTable.conforms))
        ]
    )
}
