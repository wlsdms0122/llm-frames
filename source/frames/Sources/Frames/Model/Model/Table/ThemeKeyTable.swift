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
            KeyRule("shapes", .map(.object(ShapeKeyTable.style), kind: "shapes")),
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
            KeyRule("font", .list(.name)),
            KeyRule("size", .number),
            KeyRule("weight", .fontWeight),
            KeyRule("italic", .bool),
            KeyRule("tracking", .number),
            KeyRule("kerning", .literal(["metrics", "none"])),
            KeyRule("features", .fontFeatures),
            KeyRule("baselineShift", .number),
            KeyRule("color", .color),
            KeyRule("lineHeight", .number),
            KeyRule("stroke", .oneOf([
                .exactly(.bool(false)),
                .object(ObjectTable(
                    kind: "stroke",
                    rules: [
                        KeyRule("width", .number),
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
            KeyRule("highlight", .oneOf([
                .exactly(.bool(false)),
                .object(ObjectTable(
                    kind: "highlight",
                    rules: [
                        KeyRule("color", .color),
                        KeyRule("padding", .numbers(2)),
                        KeyRule("radius", .number)
                    ]
                ))
            ])),
            KeyRule("underline", .oneOf([
                .bool,
                .object(ObjectTable(
                    kind: "underline",
                    rules: [
                        KeyRule("width", .number),
                        KeyRule("offset", .number),
                        KeyRule("color", .color)
                    ]
                ))
            ])),
            KeyRule("placement", .literal(VocabularyTable.placementNames)),
            KeyRule("offset", .number),
            KeyRule("align", .literal(["left", "center", "right"])),
            KeyRule("lines", .positiveInteger)
        ]
    )
    // A title's `character` and `paragraph`: the keys of a text style it merges over its runs' styles and over its
    // style's paragraph attributes.
    static let character = ObjectTable(
        kind: "character",
        rules: style.rules.filter { characterKeys.contains($0.name) }
    )
    static let paragraph = ObjectTable(
        kind: "paragraph",
        rules: style.rules.filter { ["align", "lineHeight", "background"].contains($0.name) }
    )
    static let characterKeys = [
        "font", "size", "weight", "italic", "tracking", "kerning", "features", "baselineShift", "color", "stroke",
        "highlight", "underline"
    ]
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
            KeyRule("shape", ChoiceKeyTable.wholeAnimation),
            KeyRule("media", ChoiceKeyTable.wholeAnimation),
            KeyRule("adjust", ChoiceKeyTable.wholeAnimation)
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
}
