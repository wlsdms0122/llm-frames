//
//  ChoiceKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The preset choices, as a clip, a theme's `defaults` and a template's arguments and options all write them. In an
// object choice the name alone is the string form, so `preset` needs another key beside it. An object without `preset`
// changes the choice below it, the theme's default for a clip or a weaker theme's, which resolve and the theme merge
// check, and an animation choice's plays the sides it writes where the choice below plays no span.
enum ChoiceKeyTable {
    static let argumentsKind = "preset arguments"
    static let arguments = ValueType.map(.presetArgument, kind: argumentsKind)
    static let transition = ValueType.oneOf([
        .name,
        .object(ObjectTable(
            kind: "transition choice",
            rules: [
                KeyRule("preset", .name),
                KeyRule("seconds", .number(.positive)),
                KeyRule("args", arguments)
            ],
            groups: [KeyGroup(keys: ["seconds", "args"], isExclusive: false)]
        ))
    ])
    // A side of an animation choice takes the span of its own name from one preset, named alone or with its
    // arguments.
    static let animationSide = ValueType.oneOf([
        .name,
        .object(ObjectTable(
            kind: "animation side",
            rules: [
                KeyRule("preset", .name, isRequired: true),
                KeyRule("args", arguments, isRequired: true)
            ]
        ))
    ])
    // A clip's choice and a theme's title default may play by unit, which resolve allows on a title only.
    static let animation = ValueType.oneOf([.name, .object(animationChoice(rules: unitRules))])
    // A theme's default for shapes, media clips and adjustment clips, which have no units.
    static let wholeAnimation = ValueType.oneOf([.name, .object(animationChoice(rules: []))])
    static let filterKind = "filter choice"
    static let filter = ValueType.filterChoice
    // One preset of a filter choice, a name or a preset entry, alone or in its list. An op written in place is checked
    // by its op's table.
    static let filterPreset = ValueType.oneOf([
        .name,
        .object(ObjectTable(
            kind: filterKind,
            rules: [
                KeyRule("kind", .literal([ValueStructure.presetKind]), isRequired: true),
                KeyRule("preset", .name),
                KeyRule("args", arguments),
                KeyRule("mix", .number(.range(0...1)))
            ],
            groups: [KeyGroup(keys: ["args", "mix"], isExclusive: false)]
        ))
    ])
    static let audioFilter = ValueType.audioFilterChoice
    // One preset of an audio filter choice, a name or a preset entry, alone or in its list. An op written in place is
    // checked by its op's table.
    static let audioFilterPreset = ValueType.oneOf([
        .name,
        .object(ObjectTable(
            kind: AudioFilterKeyTable.kind,
            rules: [
                KeyRule("kind", .literal([ValueStructure.presetKind]), isRequired: true),
                KeyRule("preset", .name),
                KeyRule("args", arguments),
                KeyRule("mix", .number(.range(0...1)))
            ],
            groups: [KeyGroup(keys: ["args", "mix"], isExclusive: false)]
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

        case animation, wholeAnimation, animationSide:
            .animation

        case filter, filterPreset:
            .filter

        case audioFilter, audioFilterPreset:
            .audio

        default:
            nil
        }
    }

    private static let unitRules = [
        KeyRule("by", .literal(TextUnit.allCases.map(\.rawValue))),
        KeyRule("stagger", .number(.nonNegative)),
        KeyRule("order", .literal(UnitOrder.allCases.map(\.rawValue)))
    ]

    // `preset` with its `args` gives the spans, and `entrance` and `exit` each replace one of them.
    private static func animationChoice(rules: [KeyRule]) -> ObjectTable {
        ObjectTable(
            kind: "animation choice",
            rules: [
                KeyRule("preset", .name),
                KeyRule("args", arguments),
                KeyRule("entrance", animationSide),
                KeyRule("exit", animationSide)
            ] + rules,
            groups: [KeyGroup(keys: ["args", "entrance", "exit"] + rules.map(\.name), isExclusive: false)]
        )
    }
}
