//
//  ClipKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ClipKeyTable {
    static let kindKeys = ["media", "title", "shape", "adjust", "solid"]

    static func kindKeys(in place: ClipPlace) -> [String] {
        place == .storyline ? ["media", "solid"] : ["media", "title", "shape", "adjust"]
    }

    static func table(
        for kind: ClipKind,
        in place: ClipPlace
    ) -> ObjectTable {
        let names = keys(for: kind, in: place).filter { takes($0, kind: kind) }
        let rules = names.map { name in
            // Which kind of text a title is belongs to the document, so it names its style.
            KeyRule(name, type(of: name, for: kind, in: place), isRequired: name == "style" && kind == .title)
        }

        return ObjectTable(kind: kind.label, rules: rules)
    }

    // The preset choice a clip key takes, which is the same for every kind and place, or nil for a key that takes none.
    // A media clip of a video or a compound clip written with `"picture": false`, which takes only its media's sound
    // and so an audio clip's keys, and `picture`.
    // A compound clip's or a template instance's sound is a mix of several sounds, which takes no `audioFilter`.
    static func soundTable(
        of media: MediaKind,
        in place: ClipPlace
    ) -> ObjectTable {
        let audio = table(for: .media(.audio), in: place)
        let picture = KeyRule("picture", .bool)
        guard media == .sequence else { return ObjectTable(kind: audio.kind, rules: audio.rules + [picture]) }

        let keyframes = keyframeTable(for: .media(.audio), in: place)
        let mixed = ObjectTable(
            kind: keyframes.kind,
            rules: keyframes.rules.filter { $0.name != "audioFilter" },
            group: KeyGroup(keys: keyframable(for: .media(.audio), in: place).filter { $0 != "audioFilter" }, isExclusive: false)
        )
        let rules = audio.rules.filter { $0.name != "audioFilter" }.map { rule in
            rule.name == "keyframes" ? KeyRule("keyframes", .list(.object(mixed))) : rule
        }
        return ObjectTable(kind: audio.kind, rules: rules + [picture])
    }

    static func choice(ofKey name: String) -> ValueType? {
        switch name {
        case "animation":
            ChoiceKeyTable.animation

        case "filter", "adjust":
            ChoiceKeyTable.filter

        case "audioFilter":
            ChoiceKeyTable.audioFilter

        case "transition":
            ChoiceKeyTable.transition

        default:
            nil
        }
    }

    static func keyframable(
        for kind: ClipKind,
        in place: ClipPlace
    ) -> [String] {
        keyframableKeys(for: kind, in: place).filter { takes($0, kind: kind) }
    }

    private static func keyframableKeys(
        for kind: ClipKind,
        in place: ClipPlace
    ) -> [String] {
        switch (place, kind) {
        case (.storyline, .media(.video)), (.storyline, .media(.sequence)):
            [
                "crop", "position", "scale", "rotation", "opacity", "mask", "filter", "radius", "border", "shadow",
                "volume", "pan", "audioFilter", "timeRemap"
            ]

        case (.storyline, .media):
            ["crop", "position", "scale", "rotation", "opacity", "mask", "filter", "radius", "border", "shadow"]

        case (_, .media(.audio)):
            ["volume", "pan", "audioFilter"]

        case (_, .media(.video)), (_, .media(.sequence)):
            [
                "position", "scale", "rotation", "opacity", "crop", "mask", "filter", "radius", "border", "shadow",
                "volume", "pan", "audioFilter", "timeRemap"
            ]

        case (_, .media):
            ["position", "scale", "rotation", "opacity", "crop", "mask", "filter", "radius", "border", "shadow"]

        case (_, .title):
            ["position", "scale", "rotation", "opacity", "mask"]

        case (_, .shape):
            [
                "area", "width", "height", "points", "position", "scale", "rotation", "opacity", "trim", "radius", "outset",
                "fill", "stroke", "shadow", "mask"
            ]
            .filter(keys(for: kind, in: place).contains)

        case (_, .adjust):
            ["opacity", "mask", "adjust"]

        case (_, .solid):
            []
        }
    }

    static func keyframeTable(
        for kind: ClipKind,
        in place: ClipPlace
    ) -> ObjectTable {
        let properties = keyframable(for: kind, in: place)
        let rules = [
            KeyRule("at", .number, isRequired: true),
            KeyRule("ease", .ease)
        ] + properties.map { property in
            let type = type(of: property, for: kind, in: place)
            return KeyRule(property, lookKeys.contains(property) ? keyframed(type) : type)
        }

        return ObjectTable(
            kind: "keyframe",
            rules: rules,
            group: KeyGroup(keys: properties, isExclusive: false)
        )
    }

    // A run of a title's list: its text, and the theme text style it is set in, the clip's when it names none.
    static let run = ObjectTable(
        kind: "run",
        rules: [
            KeyRule("text", .text, isRequired: true),
            KeyRule("style", .name)
        ]
    )

    // Properties written only in keyframes, so a static value stops.
    static let keyframedOnly = ["timeRemap"]

    // Keys of the look, timed leaf by leaf over the merged value: a keyframe may write any of their leaves, `null` for
    // the merged value's, and a clip may write them statically beside keyframes, which timing checks leaf by leaf.
    static let lookKeys = ["radius", "outset", "fill", "stroke", "shadow", "border", "filter", "adjust", "audioFilter"]

    // The keys of every clip with a picture, which each kind's row starts with.
    private static let everyClip = [
        "id", "metadata", "at", "lane", "parent", "opacity", "blend", "mask", "trackMatte", "track", "animation",
        "keyframes"
    ]

    // The keys every shape kind takes, then those of its geometry: a box for a rect or an ellipse, points for a path. A
    // key a kind does not take stops as an unknown key.
    private static let everyShape = [
        "shape", "style", "position", "anchor", "fill", "stroke", "trim", "shadow", "scale", "rotation"
    ]

    // Each row is the specification's key table row, in its order, so the two are compared line by line.
    private static func keys(
        for kind: ClipKind,
        in place: ClipPlace
    ) -> [String] {
        switch (place, kind) {
        case (.storyline, .media(.video)), (.storyline, .media(.sequence)):
            return [
                "id", "metadata", "media", "in", "out", "speed", "crop", "filter", "transition", "anchor", "position",
                "scale", "rotation", "opacity", "blend", "mask", "trackMatte", "track", "radius", "border", "shadow",
                "volume", "pan", "fadeIn", "fadeOut", "audioFilter", "keyframes", "connected"
            ]

        case (_, .solid):
            return ["id", "metadata", "solid", "duration", "transition", "connected"]

        case (.storyline, .media):
            return [
                "id", "metadata", "media", "duration", "crop", "filter", "transition", "anchor", "position", "scale",
                "rotation", "opacity", "blend", "mask", "trackMatte", "radius", "border", "shadow", "keyframes",
                "connected"
            ]

        case (_, .media(.audio)):
            return [
                "id", "metadata", "at", "media", "in", "out", "speed", "loop", "volume", "pan", "fadeIn", "fadeOut",
                "audioFilter", "keyframes"
            ]

        case (_, .media(.video)), (_, .media(.sequence)):
            return everyClip + [
                "media", "picture", "in", "out", "speed", "loop", "volume", "pan", "fadeIn", "fadeOut", "audioFilter",
                "placement", "position", "anchor", "scale", "rotation", "crop", "conform", "filter", "width", "height",
                "radius", "border", "shadow"
            ]

        case (_, .media):
            return everyClip + [
                "media", "placement", "position", "anchor", "scale", "rotation", "crop", "conform", "filter", "width",
                "height", "radius", "border", "shadow"
            ]

        case (_, .title):
            return everyClip + ["title", "style", "width", "placement", "position", "anchor", "scale", "rotation"]

        case let (_, .shape(shape)):
            return everyClip + everyShape + shapeKeys(of: shape)

        case (_, .adjust):
            return everyClip + ["adjust"]
        }
    }

    private static func type(
        of name: String,
        for kind: ClipKind,
        in place: ClipPlace
    ) -> ValueType {
        switch name {
        case "id":
            .identifier

        case "metadata":
            .anyObject

        case "media":
            .media

        case "at":
            takesSingleStart(kind) ? .oneOf([.number, .numbers(2)]) : .numbers(2)

        case "lane":
            .integer

        case "keyframes":
            .list(.object(keyframeTable(for: kind, in: place)))

        case "connected":
            .clips(.connected)

        case "track":
            .oneOf([.exactly(.bool(true)), .area])

        case "crop":
            .crop

        case "solid":
            .color

        case "loop", "closed", "picture":
            .bool

        // A media clip's and a storyline clip's shadow take the same forms as a shape's.
        case "shadow":
            ShapeKeyTable.shadow

        case "fill":
            ShapeKeyTable.fill

        case "stroke":
            ShapeKeyTable.stroke

        case "trim":
            .fractions(2)

        case "points":
            .points

        case "anchor", "placement":
            .literal(VocabularyTable.placementNames)

        case "position":
            AreaKeyTable.point

        case "area":
            .area

        case "conform":
            .literal(VocabularyTable.conforms)

        case "mask":
            .masks

        case "trackMatte":
            .object(ObjectTable(
                kind: "track matte",
                rules: [
                    KeyRule("clip", .name, isRequired: true),
                    KeyRule("mode", .literal(TrackMatteMode.allCases.map(\.rawValue)), isRequired: true),
                    KeyRule("invert", .bool)
                ]
            ))

        case "blend":
            .literal(VocabularyTable.blendModes)

        case "border":
            .oneOf([.exactly(.bool(true)), .color])

        case "title":
            .runs

        case "style", "parent":
            .name

        case "shape":
            .literal(VocabularyTable.shapes)

        // A box is drawn or wraps text, so it has some size, and a corner cannot curve inwards.
        case "width", "height":
            .positiveNumber

        case "radius":
            .nonNegativeNumber

        // An outset grows the outline a shape draws around its geometry, and a smaller outline is a smaller geometry.
        case "outset":
            .nonNegativeNumber

        // A sound sits between the left channel (-1) and the right (1).
        case "pan":
            .signedFraction

        default:
            choice(ofKey: name) ?? .number
        }
    }

    // A look key's type in a keyframe: each leaf may be `null`, and a length may be 0 or less, since timing checks a
    // leaf two keyframes write against its domain and one a single keyframe writes as a static value.
    private static func keyframed(_ type: ValueType) -> ValueType {
        type == ChoiceKeyTable.filter || type == ChoiceKeyTable.audioFilter
            ? ChoiceKeyTable.filterKeyframe
            : .oneOf([.exactly(.null), loosened(type)])
    }

    private static func loosened(_ type: ValueType) -> ValueType {
        switch type {
        case let .oneOf(types):
            .oneOf(types.map(loosened))

        case let .object(table):
            .object(ObjectTable(
                kind: table.kind,
                rules: table.rules.map { KeyRule($0.name, keyframed($0.type)) },
                group: table.group
            ))

        case .positiveNumber, .nonNegativeNumber:
            .number

        default:
            type
        }
    }

    private static func shapeKeys(of shape: String) -> [String] {
        switch ShapeKind(rawValue: shape) {
        case .rect:
            ["area", "width", "height", "placement", "radius", "outset"]

        case .ellipse:
            ["area", "width", "height", "placement", "outset"]

        case .path:
            ["points", "closed"]

        case .none:
            []
        }
    }

    // A compound clip's sound is a mix of several sounds, so it takes no `audioFilter`; its clips take their own.
    private static func takes(
        _ key: String,
        kind: ClipKind
    ) -> Bool {
        key != "audioFilter" || kind != .media(.sequence)
    }

    private static func takesSingleStart(_ kind: ClipKind) -> Bool {
        switch kind {
        case .media(.video), .media(.sequence), .media(.audio):
            true

        default:
            false
        }
    }
}
