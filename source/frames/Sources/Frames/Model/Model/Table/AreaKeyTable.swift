//
//  AreaKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum AreaKeyTable {
    // A point as `position` takes it: `[x, y]`, or the named point of an area.
    static let point = ValueType.oneOf([.numbers(2, .any), .object(namedPoint)])
    static let clip = ObjectTable(
        kind: "clip area",
        rules: [
            KeyRule("clip", .text, isRequired: true),
            KeyRule("padding", .number(.nonNegative))
        ]
    )
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
