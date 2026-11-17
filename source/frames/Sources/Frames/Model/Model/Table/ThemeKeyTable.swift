//
//  ThemeKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ThemeKeyTable {
    static let theme = ObjectTable(
        kind: "theme",
        rules: [
            KeyRule("baseWidth", .number),
            KeyRule("font", .list(.name)),
            KeyRule("colors", .map(.hexColor, kind: "colors")),
            KeyRule("styles", .map(.object(style), kind: "styles")),
            KeyRule("shapes", .object(shapes)),
            KeyRule("placement", .object(group("placement", ["padding"]))),
            KeyRule("border", .object(ObjectTable(
                kind: "border",
                rules: [
                    KeyRule("width", .number),
                    KeyRule("color", .color)
                ]
            ))),
            KeyRule("shadow", .object(ObjectTable(
                kind: "shadow",
                rules: [
                    KeyRule("radius", .number),
                    KeyRule("offset", .numbers(2)),
                    KeyRule("color", .color)
                ]
            ))),
            KeyRule("defaults", .object(defaults))
        ]
    )
    static let style = ObjectTable(
        kind: "style",
        rules: [
            KeyRule("size", .number),
            KeyRule("weight", .literal(["regular", "bold"])),
            KeyRule("color", .color),
            KeyRule("emphasis", .color),
            KeyRule("lineHeight", .number),
            KeyRule("stroke", .oneOf([
                .exactly(.bool(false)),
                .object(ObjectTable(
                    kind: "stroke",
                    rules: [
                        KeyRule("width", .number, isRequired: true),
                        KeyRule("color", .color)
                    ]
                ))
            ])),
            KeyRule("background", .oneOf([
                .exactly(.bool(false)),
                .object(ObjectTable(
                    kind: "background",
                    rules: [
                        KeyRule("color", .color),
                        KeyRule("padding", .numbers(2)),
                        KeyRule("radius", .number)
                    ]
                ))
            ])),
            KeyRule("placement", .literal(VocabularyTable.placementNames)),
            KeyRule("offset", .number),
            KeyRule("align", .literal(["left", "center", "right"])),
            KeyRule("lines", .positiveInteger)
        ]
    )
    static let shapes = ObjectTable(
        kind: "shapes",
        rules: [
            KeyRule("box", .object(shape("box", ["width", "radius"]))),
            KeyRule("fill", .object(shape("fill", []))),
            KeyRule("dim", .object(shape("dim", []))),
            KeyRule("arrow", .object(shape("arrow", ["width", "length", "head"])))
        ]
    )
    static let defaults = ObjectTable(
        kind: "defaults",
        rules: [
            KeyRule("transition", ChoiceKeyTable.transition),
            KeyRule("filter", ChoiceKeyTable.filter),
            KeyRule("animation", .object(animationDefaults))
        ]
    )
    static let animationDefaults = ObjectTable(
        kind: "animation defaults",
        rules: [
            KeyRule("title", titleAnimations),
            KeyRule("shape", ChoiceKeyTable.animation),
            KeyRule("media", ChoiceKeyTable.animation),
            KeyRule("adjust", ChoiceKeyTable.animation)
        ]
    )
    // A map's kind is not readable from its value type, so it is named on its own.
    static let titleAnimationKind = "title animations"
    static let titleAnimations = ValueType.map(ChoiceKeyTable.animation, kind: titleAnimationKind)

    private static func group(
        _ kind: String,
        _ names: [String]
    ) -> ObjectTable {
        ObjectTable(kind: kind, rules: names.map { KeyRule($0, .number) })
    }

    private static func shape(
        _ kind: String,
        _ lengths: [String]
    ) -> ObjectTable {
        ObjectTable(kind: kind, rules: lengths.map { KeyRule($0, .number) } + [KeyRule("color", .color)])
    }
}
