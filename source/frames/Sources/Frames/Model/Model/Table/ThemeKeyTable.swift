//
//  ThemeKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A theme's keys and a text style's, read from their look structures. A theme's `colors` are written as hex, and its
// `styles`, `shapes` and `defaults` have tables of their own.
enum ThemeKeyTable {
    static let theme = ObjectTable(
        kind: "theme",
        rules: [
            KeyRule("baseWidth", look("baseWidth")),
            KeyRule("font", look("font")),
            KeyRule("colors", .map(.hexColor, kind: "colors")),
            KeyRule("styles", .map(.object(style), kind: "styles")),
            KeyRule("shapes", .map(.object(ShapeKeyTable.style), kind: "shapes")),
            KeyRule("placement", look("placement")),
            KeyRule("border", look("border")),
            KeyRule("shadow", look("shadow")),
            KeyRule("defaults", .object(defaults))
        ]
    )
    static let style = ObjectTable(written: LookStructureTable.textStyle, kind: "style")
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

    private static func look(_ key: String) -> ValueType {
        ValueType(structure: LookStructureTable.theme.structure(ofMember: key), kind: key)
    }
}
