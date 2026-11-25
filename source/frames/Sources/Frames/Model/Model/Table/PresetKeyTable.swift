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
            KeyRule("seconds", .number(.any), isRequired: true),
            KeyRule("ease", .ease),
            KeyRule("over", .literal(["incoming", "outgoing"])),
            KeyRule("audio", .literal(CrossfadeCurve.allCases.map(\.rawValue))),
            KeyRule("incoming", .object(transitionSpan("incoming"))),
            KeyRule("outgoing", .object(transitionSpan("outgoing"))),
            KeyRule("cover", .kinds(cover)),
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
    static let audio = ObjectTable(
        kind: "audio preset",
        rules: [
            KeyRule("description", .text, isRequired: true),
            KeyRule("params", .parameters(ParameterKeyTable.audioPreset)),
            KeyRule("ops", .list(.audioOperation), isRequired: true)
        ]
    )
    // A head's points are plain numbers in its units, a vertex a point or `{vertex, inTangent, outTangent}`.
    static let head = ObjectTable(
        kind: "head",
        rules: [
            KeyRule("description", .text, isRequired: true),
            KeyRule("points", .list(.oneOf([
                .numbers(2, .any),
                .object(ObjectTable(
                    kind: "head vertex",
                    rules: [
                        KeyRule("vertex", .numbers(2, .any), isRequired: true),
                        KeyRule("inTangent", PathKeyTable.tangent),
                        KeyRule("outTangent", PathKeyTable.tangent)
                    ]
                ))
            ])), isRequired: true),
            KeyRule("length", .number(.any), isRequired: true),
            KeyRule("inset", .number(.any), isRequired: true)
        ]
    )
    static let spanKey = ObjectTable(
        kind: "span key",
        rules: [KeyRule("t", .number(.any), isRequired: true)] + motionProperties.map { property in
            KeyRule(property, ["opacity", "reveal"].contains(property) ? .number(.range(0...1)) : .number(.any))
        }
    )

    private static let revealFrom = KeyRule("revealFrom", .literal(VocabularyTable.sides))
    // A cover is a colour or media, in the words a clip uses for the same things (FRAMES-14).
    private static let cover = KindTable(
        kind: "cover",
        tables: [
            "solid": ObjectTable(
                kind: "solid cover",
                rules: [coverKind("solid"), KeyRule("color", .color, isRequired: true), KeyRule("ease", .ease), coverKeys]
            ),
            // Only a media cover is read in a colour space.
            "media": ObjectTable(
                kind: "media cover",
                rules: [
                    coverKind("media"),
                    KeyRule("media", MediaKeyTable.file, isRequired: true),
                    KeyRule("colorSpace", .literal(VocabularyTable.colorSpaces)),
                    KeyRule("ease", .ease),
                    coverKeys
                ]
            )
        ]
    )
    private static let coverKeys = KeyRule("keys", .list(.object(ObjectTable(
        kind: "cover key",
        rules: [
            KeyRule("t", .number(.any), isRequired: true),
            KeyRule("opacity", .number(.range(0...1)))
        ]
    ))))
    private static let matte = ObjectTable(
        kind: "matte",
        rules: [
            KeyRule("media", MediaKeyTable.file, isRequired: true),
            KeyRule("colorSpace", .literal(VocabularyTable.colorSpaces)),
            KeyRule("softness", .number(.range(0...1))),
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
                KeyRule(length, .number(.any), isRequired: true),
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

    private static func coverKind(_ name: String) -> KeyRule {
        KeyRule("kind", .literal([name]), isRequired: true)
    }
}
