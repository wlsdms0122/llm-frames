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
            // An arrow's side is the document's, since the engine has no rule to choose one.
            KeyRule(name, type(of: name, for: kind, in: place), isRequired: name == "style" || name == "side")
        }

        return ObjectTable(kind: kind.label, rules: rules)
    }

    static func keyframable(
        for kind: ClipKind,
        in place: ClipPlace
    ) -> [String] {
        switch (place, kind) {
        case (.storyline, .media(.video)), (.storyline, .media(.sequence)):
            ["crop", "position", "scale", "rotation", "opacity", "volume"]

        case (.storyline, _):
            ["crop", "position", "scale", "rotation", "opacity"]

        case (_, .media(.audio)):
            ["volume"]

        case (_, .media(.video)), (_, .media(.sequence)):
            ["position", "scale", "rotation", "opacity", "crop", "volume"]

        case (_, .media):
            ["position", "scale", "rotation", "opacity", "crop"]

        case (_, .title):
            ["position", "scale", "rotation", "opacity"]

        case (_, .shape), (_, .adjust), (_, .solid):
            ["area", "opacity"]
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

    // A storyline clip with media takes a transform and draws its box as a media clip does, with no placement and no
    // parent.
    private static let storylineTransform = [
        "anchor", "position", "scale", "rotation", "opacity", "blend", "radius", "border", "shadow"
    ]

    private static func keys(
        for kind: ClipKind,
        in place: ClipPlace
    ) -> [String] {
        switch (place, kind) {
        case (.storyline, .media(.video)), (.storyline, .media(.sequence)):
            return [
                "id", "metadata", "media", "in", "track", "out", "speed", "crop", "filter", "transition"
            ] + storylineTransform + ["volume", "fadeIn", "fadeOut", "keyframes", "connected"]

        case (.storyline, .solid):
            return ["id", "metadata", "solid", "duration", "transition", "connected"]

        case (.storyline, _):
            return ["id", "metadata", "media", "duration", "crop", "filter", "transition"] + storylineTransform
                + ["keyframes", "connected"]

        case (_, .media(.audio)):
            return ["id", "metadata", "at", "media", "in", "out", "speed", "loop", "volume", "fadeIn", "fadeOut", "keyframes"]

        case (_, .media(.video)), (_, .media(.sequence)):
            return everyClip + [
                "track", "anchor", "media", "in", "out", "speed", "loop", "volume", "fadeIn", "fadeOut",
                "placement", "position", "scale", "rotation", "crop", "conform", "filter", "blend",
                "width", "height", "radius", "border", "shadow"
            ]

        case (_, .media):
            return everyClip + [
                "track", "anchor", "media", "placement", "position", "scale", "rotation", "crop",
                "conform", "filter", "blend", "width", "height", "radius", "border", "shadow"
            ]

        case (_, .title):
            return everyClip + [
                "track", "anchor", "title", "style", "width", "placement", "position", "scale",
                "rotation", "blend"
            ]

        case let (_, .shape(shape)):
            let side = shape == "arrow" ? ["side"] : []
            return everyClip + ["shape", "area", "track", "color", "blend"] + side

        case (_, .adjust), (_, .solid):
            return everyClip + ["adjust", "area", "track"]
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

        case "solid", "color":
            .color

        case "loop", "shadow":
            .bool

        case "anchor", "placement":
            .literal(VocabularyTable.placementNames)

        case "position":
            .oneOf([.numbers(2), .object(AreaKeyTable.point)])

        case "area":
            .area

        case "conform":
            .literal(VocabularyTable.conforms)

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

        case "side":
            .literal(VocabularyTable.sides)

        // A box is drawn or wraps text, so it has some size, and a corner cannot curve inwards.
        case "width", "height":
            .positiveNumber

        case "radius":
            .nonNegativeNumber

        default:
            .number
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
