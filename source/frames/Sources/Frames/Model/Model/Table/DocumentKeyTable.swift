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
            KeyRule("kind", .literal(VocabularyTable.documentKinds), isRequired: true),
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
    static let image = ObjectTable(
        kind: "image",
        rules: [
            KeyRule("kind", .literal(VocabularyTable.documentKinds), isRequired: true),
            KeyRule("source", .media, isRequired: true),
            KeyRule("time", .number),
            KeyRule("theme", theme),
            KeyRule("params", .parameters),
            KeyRule("ops", .operations)
        ]
    )
    static let layout = ObjectTable(
        kind: "layout",
        rules: [
            KeyRule("kind", .literal(VocabularyTable.documentKinds), isRequired: true),
            KeyRule("theme", theme),
            KeyRule("params", .parameters),
            KeyRule("banner", .list(ImageKeyTable.bannerLine)),
            KeyRule("columns", .integer),
            KeyRule("border", .oneOf([.bool, .color])),
            KeyRule("items", .list(.object(layoutItem)))
        ]
    )
    static let layoutItem = ObjectTable(
        kind: "layout item",
        rules: [
            KeyRule("heading", .text),
            KeyRule("image", .media, isRequired: true)
        ]
    )

    static func table(for kind: String) -> ObjectTable? {
        switch kind {
        case "sequence":
            sequence

        case "image":
            image

        case "layout":
            layout

        default:
            nil
        }
    }
}
