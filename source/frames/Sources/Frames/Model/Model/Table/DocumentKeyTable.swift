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
            KeyRule("params", .parameters(ParameterKeyTable.template)),
            KeyRule("storyline", .clips(.storyline)),
            KeyRule("clips", .clips(.sequence))
        ]
    )
    static let format = ObjectTable(
        kind: "format",
        rules: [
            KeyRule("size", .oneOf([.numbers(2), .object(contentFit)])),
            KeyRule("fps", .positiveNumber),
            KeyRule("background", .color),
            KeyRule("conform", .literal(VocabularyTable.conforms))
        ]
    )
    static let contentFit = ObjectTable(
        kind: "content fit",
        rules: [
            KeyRule("fit", .literal(["content"]), isRequired: true),
            KeyRule("margin", .margin)
        ]
    )
}
