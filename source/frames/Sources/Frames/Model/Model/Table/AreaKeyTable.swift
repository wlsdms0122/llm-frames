//
//  AreaKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum AreaKeyTable {
    // A point as `position` takes it: `[x, y]`, or the named point of an area.
    static let point = ValueType.oneOf([.numbers(2, .any), .object(namedPoint)])
    static let text = ObjectTable(
        kind: "text area",
        rules: [
            KeyRule("text", .text, isRequired: true),
            KeyRule("nth", .nonNegativeInteger),
            KeyRule("padding", .number(.nonNegative))
        ]
    )
    static let range = ObjectTable(
        kind: "text range area",
        rules: [
            KeyRule("from", .text, isRequired: true),
            KeyRule("to", .text, isRequired: true),
            KeyRule("fromNth", .nonNegativeInteger),
            KeyRule("toNth", .nonNegativeInteger),
            KeyRule("padding", .number(.nonNegative))
        ]
    )
    static let clip = ObjectTable(
        kind: "clip area",
        rules: [
            KeyRule("clip", .text, isRequired: true),
            KeyRule("padding", .number(.nonNegative))
        ]
    )
    // The keys of the text forms, which a clip area does not mix with.
    static let textKeys = ["text", "nth", "from", "to", "fromNth", "toNth"]
    static let cropScale = ObjectTable(
        kind: "crop",
        rules: [
            KeyRule("scale", .number(.positive), isRequired: true)
        ]
    )
    static let namedPoint = ObjectTable(
        kind: "area point",
        rules: [
            KeyRule("area", .area, isRequired: true),
            KeyRule("point", .literal(VocabularyTable.placementNames), isRequired: true)
        ]
    )
}
