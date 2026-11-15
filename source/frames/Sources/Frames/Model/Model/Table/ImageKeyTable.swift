//
//  ImageKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ImageKeyTable {
    static let operationKeys = ["crop", "resize", "pad", "shape", "adjust", "title", "banner", "border"]
    static let bannerLine = ValueType.oneOf([
        .text,
        .object(ObjectTable(
            kind: "banner line",
            rules: [
                KeyRule("text", .text, isRequired: true),
                KeyRule("style", .name)
            ]
        ))
    ])

    static func table(
        for operation: String,
        shape: String?
    ) -> ObjectTable {
        let common = [
            KeyRule("id", .identifier),
            KeyRule("metadata", .anyObject)
        ]

        switch operation {
        case "crop":
            return ObjectTable(kind: operation, rules: common + [KeyRule("crop", .area)])

        case "resize":
            return ObjectTable(kind: operation, rules: common + [KeyRule("resize", .object(resize))])

        case "pad":
            return ObjectTable(
                kind: operation,
                rules: common + [
                    KeyRule("pad", .oneOf([.number, .numbers(2), .numbers(4)])),
                    KeyRule("color", .color)
                ]
            )

        case "shape":
            let side = shape == "arrow" ? [KeyRule("side", .literal(VocabularyTable.sides), isRequired: true)] : []
            return ObjectTable(
                kind: shape ?? operation,
                rules: common + [
                    KeyRule("shape", .literal(VocabularyTable.shapes)),
                    KeyRule("area", .area),
                    KeyRule("label", .text),
                    KeyRule("color", .color)
                ] + side
            )

        case "adjust":
            return ObjectTable(
                kind: operation,
                rules: common + [
                    KeyRule("adjust", ChoiceKeyTable.filter),
                    KeyRule("area", .area)
                ]
            )

        case "title":
            return ObjectTable(
                kind: operation,
                rules: common + [
                    KeyRule("title", .text),
                    KeyRule("position", .oneOf([.numbers(2), .object(AreaKeyTable.point)])),
                    KeyRule("anchor", .literal(VocabularyTable.placementNames)),
                    KeyRule("style", .name, isRequired: true),
                    KeyRule("width", .number)
                ]
            )

        case "banner":
            return ObjectTable(
                kind: operation,
                rules: common + [
                    KeyRule("banner", .list(bannerLine)),
                    KeyRule("edge", .literal(["top", "bottom"]))
                ]
            )

        default:
            return ObjectTable(
                kind: operation,
                rules: common + [KeyRule("border", .oneOf([.exactly(.bool(true)), .color]))]
            )
        }
    }

    private static let resize = ObjectTable(
        kind: "resize",
        rules: [
            KeyRule("scale", .number),
            KeyRule("width", .number),
            KeyRule("height", .number)
        ],
        group: KeyGroup(keys: ["scale", "width", "height"], isExclusive: true)
    )
}
