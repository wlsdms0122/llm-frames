//
//  ClipKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ClipKeyTable {
    // The kinds a clip's `kind` names at its place: a storyline clip is media or a solid, and a connected or a sequence
    // clip any other kind.
    static func kinds(in place: ClipPlace) -> [String] {
        place == .storyline
            ? ["media", "solid"]
            : ["media", "audio", "title"] + VocabularyTable.shapes + ["adjustment", "null"]
    }

    static func table(
        for kind: ClipKind,
        in place: ClipPlace
    ) -> ObjectTable {
        let names = keys(for: kind, in: place).filter { takes($0, kind: kind) }
        let rules = names.map { name in
            KeyRule(name, type(of: name, for: kind, in: place), isRequired: isRequired(name, kind: kind))
        }

        return ObjectTable(kind: kind.label, rules: rules)
    }

    // The preset choice a clip key takes, which is the same for every kind and place, or nil for a key that takes none.
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
                "crop", "position", "scale", "rotation", "cornerPin", "opacity", "mask", "filter", "radius", "border",
                "shadow", "volume", "pan", "audioFilter", "timeRemap"
            ]

        case (.storyline, .media):
            ["crop", "position", "scale", "rotation", "cornerPin", "opacity", "mask", "filter", "radius", "border", "shadow"]

        case (_, .media(.audio)):
            ["volume", "pan", "audioFilter"]

        case (_, .media(.video)), (_, .media(.sequence)):
            [
                "position", "scale", "rotation", "cornerPin", "opacity", "crop", "mask", "filter", "radius", "border",
                "shadow", "volume", "pan", "audioFilter", "timeRemap"
            ]

        case (_, .media):
            ["position", "scale", "rotation", "cornerPin", "opacity", "crop", "mask", "filter", "radius", "border", "shadow"]

        case (_, .title):
            ["position", "scale", "rotation", "cornerPin", "opacity", "mask"] + titleLookKeys

        case (_, .shape):
            [
                "area", "width", "height", "points", "position", "scale", "rotation", "cornerPin", "opacity", "trim",
                "radius", "outset", "fill", "stroke", "shadow", "mask"
            ]
            .filter(keys(for: kind, in: place).contains)

        case (_, .adjust):
            ["opacity", "mask", "adjust"]

        case (_, .solid):
            ["color"]

        case (_, .null):
            ["area", "width", "height", "position", "scale", "rotation"]
        }
    }

    static func keyframeTable(
        for kind: ClipKind,
        in place: ClipPlace
    ) -> ObjectTable {
        let properties = keyframable(for: kind, in: place)
        let rules = [
            KeyRule("at", .number(.any), isRequired: true),
            KeyRule("ease", .ease)
        ] + properties.map { property in
            let type = type(of: property, for: kind, in: place)
            if lookKeys.contains(property) {
                return KeyRule(property, keyframed(type))
            }

            return KeyRule(property, leafKeys.contains(property) ? loosened(type) : type)
        }

        return ObjectTable(
            kind: "keyframe",
            rules: rules,
            groups: [KeyGroup(keys: properties, isExclusive: false)]
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

    // `track`, track data (FRAMES-12 Track data): the media time of the track's frame, and every frame followed.
    static let track = ObjectTable(
        kind: "track",
        rules: [
            KeyRule("time", .number(.any), isRequired: true),
            KeyRule("frames", .list(.object(trackDataFrame)), isRequired: true)
        ]
    )

    // A frame of track data: a media time, and the target's quad on the frame it names in media pixels.
    static let trackDataFrame = ObjectTable(
        kind: "track data frame",
        rules: [
            KeyRule("time", .number(.any), isRequired: true),
            KeyRule("quad", .mediaQuad, isRequired: true)
        ]
    )

    // Properties written only in keyframes, so a static value stops.
    static let keyframedOnly = ["timeRemap"]

    // Keys of the look, timed leaf by leaf over the merged value: a keyframe may write any of their leaves, `null` for
    // the merged value's, and a clip may write them statically beside keyframes, which timing checks leaf by leaf.
    static let lookKeys = [
        "radius", "outset", "fill", "stroke", "shadow", "border", "filter", "adjust", "mask", "audioFilter", "color"
    ] + titleLookKeys

    // Keys outside the look timed leaf by leaf, over the clip's static value and no style: a path's `points`, each
    // vertex's point and tangents a leaf of its own (FRAMES-11 Paths).
    static let leafKeys = ["points"]

    // A title's character and paragraph attributes, merged over its styles' as every look key is.
    static let titleLookKeys = ["character", "paragraph"]

    // The keys of every clip with a picture, which each kind's row starts with.
    private static let everyClip = [
        "id", "metadata", "kind", "at", "lane", "parent", "opacity", "blend", "motionBlur", "mask", "trackMatte", "track",
        "animation", "keyframes"
    ]

    // The keys every shape kind takes, then those of its geometry: a box for a rect or an ellipse, with the corner pin
    // a box takes, and points for a path. A key a kind does not take stops as an unknown key.
    private static let everyShape = [
        "style", "position", "anchor", "fill", "stroke", "trim", "shadow", "scale", "rotation"
    ]

    // Each row is the specification's key table row, in its order, so the two are compared line by line.
    private static func keys(
        for kind: ClipKind,
        in place: ClipPlace
    ) -> [String] {
        switch (place, kind) {
        case (.storyline, .media(.video)), (.storyline, .media(.sequence)):
            return [
                "id", "metadata", "kind", "media", "colorSpace", "toneMap", "in", "out", "speed", "crop", "filter",
                "transition",
                "anchor", "position", "scale", "rotation", "cornerPin", "opacity", "blend", "motionBlur", "mask",
                "trackMatte", "track", "radius", "border", "shadow", "volume", "pan", "fadeIn", "fadeOut", "audioFilter",
                "split", "keyframes", "connected"
            ]

        case (_, .solid):
            return ["id", "metadata", "kind", "color", "duration", "transition", "motionBlur", "keyframes", "connected"]

        case (.storyline, .media):
            return [
                "id", "metadata", "kind", "media", "colorSpace", "toneMap", "duration", "crop", "filter", "transition",
                "anchor", "position", "scale", "rotation", "cornerPin", "opacity", "blend", "motionBlur", "mask",
                "trackMatte", "radius", "border", "shadow", "keyframes", "connected"
            ]

        // An audio clip takes its media's sound alone, so its keys are the same whatever its media is.
        case (_, .media(.audio)):
            return [
                "id", "metadata", "kind", "at", "media", "in", "out", "speed", "loop", "volume", "pan", "fadeIn",
                "fadeOut", "audioFilter", "keyframes"
            ]

        case (_, .media(.video)), (_, .media(.sequence)):
            return everyClip + [
                "media", "colorSpace", "toneMap", "in", "out", "speed", "loop", "volume", "pan", "fadeIn",
                "fadeOut", "audioFilter", "split", "placement", "position", "anchor", "scale", "rotation", "cornerPin", "crop",
                "conform", "filter", "width", "height", "radius", "border", "shadow"
            ]

        case (_, .media):
            return everyClip + [
                "media", "colorSpace", "toneMap", "placement", "position", "anchor", "scale", "rotation", "cornerPin", "crop",
                "conform", "filter", "width", "height", "radius", "border", "shadow"
            ]

        case (_, .title):
            return everyClip + [
                "text", "style", "character", "paragraph", "width", "placement", "position", "anchor", "scale",
                "rotation", "cornerPin"
            ]

        case let (_, .shape(shape)):
            return everyClip + everyShape + shapeKeys(of: shape)

        case (_, .adjust):
            return everyClip + ["adjust"]

        // A null draws nothing, so it takes the keys that place and move a box and none of how a picture is drawn or
        // composited.
        case (_, .null):
            return [
                "id", "metadata", "kind", "at", "parent", "motionBlur", "track", "animation", "keyframes", "area",
                "width", "height", "placement", "position", "anchor", "scale", "rotation"
            ]
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
            takesSingleStart(kind) ? .oneOf([.number(.any), .numbers(2, .any)]) : .numbers(2, .any)

        case "lane":
            .integer

        case "keyframes":
            .list(.object(keyframeTable(for: kind, in: place)))

        case "connected":
            .clips(.connected)

        case "track":
            .object(ClipKeyTable.track)

        case "crop":
            .crop

        case "kind":
            .literal(kinds(in: place))

        case "color":
            .color

        case "loop", "closed", "toneMap", "motionBlur":
            .bool

        case "colorSpace":
            .literal(VocabularyTable.colorSpaces)

        // A media clip's and a storyline clip's shadow take the same forms as a shape's.
        case "shadow":
            ShapeKeyTable.shadow

        case "fill":
            ShapeKeyTable.fill

        case "stroke":
            ShapeKeyTable.stroke

        case "trim":
            .numbers(2, .range(0...1))

        case "points":
            .points(isKeyframed: false)

        case "cornerPin":
            .quad

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
            ValueType(written: LookStructureTable.border, kind: "border")

        case "text":
            .runs

        case "character":
            .object(ThemeKeyTable.character)

        case "paragraph":
            .object(ThemeKeyTable.paragraph)

        case "style", "parent":
            .name

        // A number is the same factor on both axes, and a pair a factor along each.
        case "scale":
            .oneOf([.number(.any), .numbers(2, .any)])

        // A box is drawn or wraps text, so it has some size.
        case "width", "height":
            .number(.positive)

        case "radius":
            ValueType(structure: LookStructureTable.radius, kind: name)

        case "outset":
            ValueType(structure: LookStructureTable.length, kind: name)

        // A sound sits between the left channel (-1) and the right (1).
        case "pan":
            .number(.range(-1...1))

        case "split":
            .object(ObjectTable(
                kind: "split",
                rules: [KeyRule("before", .number(.nonNegative)), KeyRule("after", .number(.nonNegative))]
            ))

        default:
            choice(ofKey: name) ?? .number(.any)
        }
    }

    // A look key's type in a keyframe: each leaf may be `null`, and its numbers may be any number, since timing checks
    // a leaf two keyframes write against its sampled domain and one a single keyframe writes against its domain. A
    // gradient's offsets may be out of order, since sampling raises each to the one before it.
    private static func keyframed(_ type: ValueType) -> ValueType {
        switch type {
        case ChoiceKeyTable.filter, ChoiceKeyTable.audioFilter:
            ChoiceKeyTable.filterKeyframe

        case .masks:
            .oneOf([.exactly(.null), loosened(.object(MaskKeyTable.keyframe)), .list(loosened(.object(MaskKeyTable.keyframe)))])

        default:
            .oneOf([.exactly(.null), loosened(type)])
        }
    }

    private static func loosened(_ type: ValueType) -> ValueType {
        switch type {
        case let .oneOf(types):
            .oneOf(types.map(loosened))

        case let .object(table):
            .object(ObjectTable(
                kind: table.kind,
                rules: table.rules.map { KeyRule($0.name, keyframed($0.type)) },
                groups: table.groups
            ))

        case .number:
            .number(.any)

        case let .numbers(count, _):
            .numbers(count, .any)

        case .stops:
            .stops(isKeyframed: true)

        case .dash:
            .dash(isKeyframed: true)

        case .points:
            .points(isKeyframed: true)

        default:
            type
        }
    }

    private static func shapeKeys(of shape: String) -> [String] {
        switch ShapeKind(rawValue: shape) {
        case .rect:
            ["area", "width", "height", "placement", "radius", "outset", "cornerPin"]

        case .ellipse:
            ["area", "width", "height", "placement", "outset", "cornerPin"]

        case .path:
            ["points", "closed"]

        case .none:
            []
        }
    }

    // A compound clip's or a template instance's pictures are working values already, so it takes no `colorSpace` or
    // `toneMap`; its clips take their own. A page of a PDF takes the keys of a still here, and what it refuses of them
    // is known only where its media is read (`MediaFile.pageRefusal`).
    private static func takes(
        _ key: String,
        kind: ClipKind
    ) -> Bool {
        switch kind {
        case .media(.sequence):
            !["colorSpace", "toneMap"].contains(key)

        default:
            true
        }
    }

    // A kind's content is required, and so is a title's style, since which kind of text a title is belongs to the
    // document. A shape's geometry and a solid's colour may be given by keyframes, so the key check checks them apart.
    private static func isRequired(
        _ key: String,
        kind: ClipKind
    ) -> Bool {
        switch (kind, key) {
        case (.media, "media"), (.title, "text"), (.title, "style"), (.adjust, "adjust"):
            true

        default:
            false
        }
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
