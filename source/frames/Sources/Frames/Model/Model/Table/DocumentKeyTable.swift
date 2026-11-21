//
//  DocumentKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum DocumentKeyTable {
    static let theme = ValueType.oneOf([.name, .object(ThemeKeyTable.theme)])
    static let sequence = ObjectTable(
        kind: "sequence",
        rules: [
            KeyRule("kind", .literal(["sequence"]), isRequired: true),
            KeyRule("format", .object(format)),
            KeyRule("theme", theme),
            KeyRule("params", .parameters(ParameterKeyTable.template)),
            KeyRule("storyline", .clips(.storyline)),
            KeyRule("clips", .clips(.sequence)),
            KeyRule("audioFilter", ChoiceKeyTable.audioFilter),
            KeyRule("keyframes", .list(.object(keyframe)))
        ]
    )
    // A keyframe of the sequence's own, on its sequence time, which writes only its `audioFilter`.
    static let keyframe = ObjectTable(
        kind: "keyframe",
        rules: [
            KeyRule("at", .number(.any), isRequired: true),
            KeyRule("ease", .ease),
            KeyRule("audioFilter", ChoiceKeyTable.filterKeyframe)
        ],
        groups: [KeyGroup(keys: ["audioFilter"], isExclusive: false)]
    )
    static let format = ObjectTable(
        kind: "format",
        rules: [
            KeyRule("size", .oneOf([.numbers(2, .any), .object(contentFit)])),
            KeyRule("fps", .number(.positive)),
            KeyRule("background", .color),
            KeyRule("conform", .literal(VocabularyTable.conforms)),
            KeyRule("colorSpace", .literal(VocabularyTable.colorSpaces)),
            KeyRule("peak", .number(.range(400...10000))),
            KeyRule("compositing", .literal(VocabularyTable.compositings))
        ]
    )
    static let contentFit = ObjectTable(
        kind: "content fit",
        rules: [
            KeyRule("fit", .literal(["content"]), isRequired: true),
            KeyRule("margin", .margin)
        ]
    )
}
