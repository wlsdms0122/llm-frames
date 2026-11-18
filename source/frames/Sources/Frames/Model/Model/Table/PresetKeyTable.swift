//
//  PresetKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum PresetKeyTable {
    static let motionProperties = ["opacity", "scale", "x", "y", "rotation", "reveal"]
    static let animation = ObjectTable(
        kind: "animation",
        rules: [
            KeyRule("description", .text, isRequired: true),
            KeyRule("params", .parameters(ParameterKeyTable.preset)),
            KeyRule("entrance", .object(timedSpan("entrance", length: "seconds"))),
            KeyRule("loop", .object(timedSpan("loop", length: "period"))),
            KeyRule("exit", .object(timedSpan("exit", length: "seconds")))
        ]
    )
    // A transition's time is its length, so its spans take neither seconds nor period.
    static let transition = ObjectTable(
        kind: "transition",
        rules: [
            KeyRule("description", .text, isRequired: true),
            KeyRule("params", .parameters(ParameterKeyTable.preset)),
            KeyRule("seconds", .number, isRequired: true),
            KeyRule("ease", .ease),
            KeyRule("over", .literal(["incoming", "outgoing"])),
            KeyRule("audio", .literal(CrossfadeCurve.allCases.map(\.rawValue))),
            KeyRule("incoming", .object(transitionSpan("incoming"))),
            KeyRule("outgoing", .object(transitionSpan("outgoing"))),
            KeyRule("cover", .object(cover)),
            KeyRule("matte", .object(matte))
        ]
    )
    static let filter = ObjectTable(
        kind: "filter",
        rules: [
            KeyRule("description", .text, isRequired: true),
            KeyRule("params", .parameters(ParameterKeyTable.filterPreset)),
            KeyRule("ops", .list(.filterOperation), isRequired: true)
        ]
    )
    static let spanKey = ObjectTable(
        kind: "span key",
        rules: [KeyRule("t", .number, isRequired: true)] + motionProperties.map { property in
            KeyRule(property, ["opacity", "reveal"].contains(property) ? .fraction : .number)
        }
    )

    private static let revealFrom = KeyRule("revealFrom", .literal(VocabularyTable.sides))
    private static let cover = ObjectTable(
        kind: "cover",
        rules: [
            KeyRule("color", .color),
            KeyRule("media", .name),
            KeyRule("ease", .ease),
            KeyRule("keys", .list(.object(ObjectTable(
                kind: "cover key",
                rules: [
                    KeyRule("t", .number, isRequired: true),
                    KeyRule("opacity", .fraction)
                ]
            ))))
        ],
        group: KeyGroup(keys: ["color", "media"], isExclusive: true)
    )
    private static let matte = ObjectTable(
        kind: "matte",
        rules: [
            KeyRule("media", .name, isRequired: true),
            KeyRule("softness", .fraction),
            KeyRule("invert", .bool),
            KeyRule("ease", .ease)
        ]
    )

    private static func timedSpan(
        _ kind: String,
        length: String
    ) -> ObjectTable {
        ObjectTable(
            kind: kind,
            rules: [
                KeyRule(length, .number, isRequired: true),
                KeyRule("ease", .ease),
                revealFrom,
                KeyRule("keys", .list(.object(spanKey)))
            ]
        )
    }

    private static func transitionSpan(_ kind: String) -> ObjectTable {
        ObjectTable(
            kind: kind,
            rules: [
                KeyRule("ease", .ease),
                revealFrom,
                KeyRule("keys", .list(.object(spanKey)))
            ]
        )
    }
}
