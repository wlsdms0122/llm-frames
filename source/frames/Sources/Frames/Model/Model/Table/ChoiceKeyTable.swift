//
//  ChoiceKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The preset choices, as a clip, a theme's `defaults` and a template's arguments and options all write them. In an
// object choice the name alone is the string form, so `preset` needs another key beside it.
enum ChoiceKeyTable {
    static let argumentsKind = "preset arguments"
    static let arguments = ValueType.map(.presetArgument, kind: argumentsKind)
    static let transition = ValueType.oneOf([
        .name,
        .object(ObjectTable(
            kind: "transition choice",
            rules: [
                KeyRule("preset", .name, isRequired: true),
                KeyRule("seconds", .positiveNumber),
                KeyRule("args", arguments)
            ],
            group: KeyGroup(keys: ["seconds", "args"], isExclusive: false)
        ))
    ])
    // A side of `{entrance, exit}` takes a preset as the whole choice does, without `{entrance, exit}` again.
    static let animationSide = ValueType.oneOf([.name, .object(presetWithArguments("animation choice"))])
    static let animation = ValueType.oneOf([
        .name,
        .object(presetWithArguments("animation choice")),
        .object(ObjectTable(
            kind: "animation choice",
            rules: [
                KeyRule("entrance", animationSide, isRequired: true),
                KeyRule("exit", animationSide, isRequired: true)
            ]
        ))
    ])
    static let filterKind = "filter choice"
    static let filter = ValueType.filterChoice
    // One preset of a filter choice, alone or in its list.
    static let filterPreset = ValueType.oneOf([.name, .object(presetWithArguments(filterKind))])

    // The kind of preset a choice of `type` names, nil for a type that is not a preset choice.
    static func presetKind(of type: ValueType) -> PresetKind? {
        switch type {
        case transition:
            .transition

        case animation, animationSide:
            .animation

        case filter, filterPreset:
            .filter

        default:
            nil
        }
    }

    private static func presetWithArguments(_ kind: String) -> ObjectTable {
        ObjectTable(
            kind: kind,
            rules: [
                KeyRule("preset", .name, isRequired: true),
                KeyRule("args", arguments, isRequired: true)
            ]
        )
    }
}
