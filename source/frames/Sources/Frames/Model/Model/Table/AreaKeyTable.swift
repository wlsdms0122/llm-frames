//
//  AreaKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum AreaKeyTable {
    static let text = ObjectTable(
        kind: "text area",
        rules: [
            KeyRule("text", .text, isRequired: true),
            KeyRule("nth", .integer)
        ]
    )
    static let range = ObjectTable(
        kind: "text range area",
        rules: [
            KeyRule("from", .text, isRequired: true),
            KeyRule("to", .text, isRequired: true),
            KeyRule("fromNth", .integer),
            KeyRule("toNth", .integer)
        ]
    )
    static let band = ObjectTable(
        kind: "band area",
        rules: [
            KeyRule("band", .area, isRequired: true)
        ]
    )
    static let cropScale = ObjectTable(
        kind: "crop",
        rules: [
            KeyRule("scale", .number, isRequired: true)
        ]
    )
    static let point = ObjectTable(
        kind: "area point",
        rules: [
            KeyRule("area", .area, isRequired: true),
            KeyRule("point", .literal(VocabularyTable.placementNames), isRequired: true)
        ]
    )
}
