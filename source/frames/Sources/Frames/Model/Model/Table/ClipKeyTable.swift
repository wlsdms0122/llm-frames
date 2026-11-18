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
        let names = keys(for: kind, in: place)
        let rules = names.map { name in
            // Which kind of text a title is belongs to the document, so it names its style.
            KeyRule(name, type(of: name, for: kind, in: place), isRequired: name == "style" && kind == .title)
        }

        return ObjectTable(kind: kind.label, rules: rules)
    }

    static func keyframable(
        for kind: ClipKind,
        in place: ClipPlace
    ) -> [String] {
        switch (place, kind) {
        case (.storyline, .media(.video)), (.storyline, .media(.sequence)):
            ["crop", "position", "scale", "rotation", "opacity", "mask", "volume", "pan"]

        case (.storyline, _):
            ["crop", "position", "scale", "rotation", "opacity", "mask"]

        case (_, .media(.audio)):
            ["volume", "pan"]

        case (_, .media(.video)), (_, .media(.sequence)):
            ["position", "scale", "rotation", "opacity", "crop", "mask", "volume", "pan"]

        case (_, .media):
            ["position", "scale", "rotation", "opacity", "crop", "mask"]

        case (_, .title):
            ["position", "scale", "rotation", "opacity", "mask"]

        case (_, .shape):
            ["area", "width", "height", "points", "position", "scale", "rotation", "opacity", "trim", "radius", "mask"]
                .filter(keys(for: kind, in: place).contains)

        case (_, .adjust), (_, .solid):
            ["opacity", "mask"]
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
        ] + properties.map { KeyRule($0, type(of: $0, for: kind, in: place)) }

        return ObjectTable(
            kind: "keyframe",
            rules: rules,
            group: KeyGroup(keys: properties, isExclusive: false)
        )
    }

    private static let everyClip = ["id", "metadata", "at", "lane", "parent", "opacity", "animation", "keyframes"]

    // The keys every shape kind takes, then those of its geometry (FRAMES-11): a box for a rect or an ellipse, points
    // for a path. A key a kind does not take stops as an unknown key.
    private static let everyShape = [
        "track", "blend", "mask", "trackMatte", "shape", "style", "anchor", "position", "scale", "rotation", "fill",
        "stroke", "trim", "shadow"
    ]

    // A storyline clip with media takes a transform and draws its box as a media clip does, with no placement and no
    // parent.
    private static let storylineTransform = [
        "anchor", "position", "scale", "rotation", "opacity", "blend", "mask", "trackMatte", "radius", "border",
        "shadow"
    ]

    private static func keys(
        for kind: ClipKind,
        in place: ClipPlace
    ) -> [String] {
        switch (place, kind) {
        case (.storyline, .media(.video)), (.storyline, .media(.sequence)):
            return [
                "id", "metadata", "media", "in", "track", "out", "speed", "crop", "filter", "transition"
            ] + storylineTransform + ["volume", "pan", "fadeIn", "fadeOut", "keyframes", "connected"]

        case (.storyline, .solid):
            return ["id", "metadata", "solid", "duration", "transition", "connected"]

        case (.storyline, _):
            return ["id", "metadata", "media", "duration", "crop", "filter", "transition"] + storylineTransform
                + ["keyframes", "connected"]

        case (_, .media(.audio)):
            return [
                "id", "metadata", "at", "media", "in", "out", "speed", "loop", "volume", "pan", "fadeIn", "fadeOut",
                "keyframes"
            ]

        case (_, .media(.video)), (_, .media(.sequence)):
            return everyClip + [
                "track", "anchor", "media", "in", "out", "speed", "loop", "volume", "pan", "fadeIn", "fadeOut",
                "placement", "position", "scale", "rotation", "crop", "conform", "filter", "blend", "mask",
                "trackMatte", "width", "height", "radius", "border", "shadow"
            ]

        case (_, .media):
            return everyClip + [
                "track", "anchor", "media", "placement", "position", "scale", "rotation", "crop",
                "conform", "filter", "blend", "mask", "trackMatte", "width", "height", "radius", "border",
                "shadow"
            ]

        case (_, .title):
            return everyClip + [
                "track", "anchor", "title", "style", "width", "placement", "position", "scale",
                "rotation", "blend", "mask", "trackMatte"
            ]

        case let (_, .shape(shape)):
            return everyClip + everyShape + shapeKeys(of: shape)

        case (_, .adjust), (_, .solid):
            return everyClip + ["adjust", "mask", "trackMatte", "track"]
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

        case "animation":
            ChoiceKeyTable.animation

        case "keyframes":
            .list(.object(keyframeTable(for: kind, in: place)))

        case "connected":
            .clips(.connected)

        case "track":
            .oneOf([.exactly(.bool(true)), .area])

        case "crop":
            .crop

        case "filter", "adjust":
            ChoiceKeyTable.filter

        case "transition":
            ChoiceKeyTable.transition

        case "solid":
            .color

        case "loop", "closed":
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
            .text

        case "style", "parent":
            .name

        case "shape":
            .literal(VocabularyTable.shapes)

        // A box is drawn or wraps text, so it has some size, and a corner cannot curve inwards.
        case "width", "height":
            .positiveNumber

        case "radius":
            .nonNegativeNumber

        // A sound sits between the left channel (-1) and the right (1).
        case "pan":
            .signedFraction

        default:
            .number
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

    private static func takesSingleStart(_ kind: ClipKind) -> Bool {
        switch kind {
        case .media(.video), .media(.sequence), .media(.audio):
            true

        default:
            false
        }
    }
}
