//
//  ChoiceKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The preset choices, as a clip, a theme's `defaults` and a template's arguments and options all write them. In an
// object choice the name alone is the string form, so `preset` needs another key beside it. An object without `preset`
// changes the choice below it, the theme's default for a clip or a weaker theme's, which resolve and the theme merge
// check.
enum ChoiceKeyTable {
    static let argumentsKind = "preset arguments"
    static let arguments = ValueType.map(.presetArgument, kind: argumentsKind)
    static let transition = ValueType.oneOf([
        .name,
        .object(ObjectTable(
            kind: "transition choice",
            rules: [
                KeyRule("preset", .name),
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
    // One preset of a filter choice, alone or in its list. An op written in place is checked by its op's table.
    static let filterPreset = ValueType.oneOf([
        .name,
        .object(ObjectTable(
            kind: filterKind,
            rules: [
                KeyRule("preset", .name),
                KeyRule("args", arguments),
                KeyRule("mix", .fraction)
            ],
            group: KeyGroup(keys: ["args", "mix"], isExclusive: false)
        ))
    ])
    static let audioFilter = ValueType.audioFilterChoice
    // One preset of an audio filter choice, alone or in its list. An op written in place is checked by its op's table.
    static let audioFilterPreset = ValueType.oneOf([
        .name,
        .object(ObjectTable(
            kind: AudioFilterKeyTable.kind,
            rules: [
                KeyRule("preset", .name),
                KeyRule("args", arguments),
                KeyRule("mix", .fraction)
            ],
            group: KeyGroup(keys: ["args", "mix"], isExclusive: false)
        ))
    ])
    // A filter choice in a keyframe writes the leaves it moves over the clip's choice: an object of an entry's
    // arguments, op parameters and `mix`, `null` or a list of those. A name stops when it is timed, since an entry's
    // preset and op are static.
    static let filterKeyframe = ValueType.oneOf([.exactly(.null), filterKeyframeEntry, .list(filterKeyframeEntry)])
    private static let filterKeyframeEntry = ValueType.oneOf([.exactly(.null), .name, .map(.anyValue, kind: filterKind)])

    // The kind of preset a choice of `type` names, nil for a type that is not a preset choice.
    static func presetKind(of type: ValueType) -> PresetKind? {
        switch type {
        case transition:
            .transition

        case animation, animationSide:
            .animation

        case filter, filterPreset:
            .filter

        case audioFilter, audioFilterPreset:
            .audio

        default:
            nil
        }
    }

    private static func presetWithArguments(_ kind: String) -> ObjectTable {
        ObjectTable(
            kind: kind,
            rules: [
                KeyRule("preset", .name),
                KeyRule("args", arguments, isRequired: true)
            ]
        )
    }
}
