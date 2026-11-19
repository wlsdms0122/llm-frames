//
//  LookStructureTable.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The structure of every value of a look, as the theme and the key tables give its keys. A keyframable key is made
// keyframable by declaring its structure here: its numbers and colours are its timed leaves, and the look merge and
// timing read nothing else of it.
enum LookStructureTable {
    static let fill = ValueStructure.forms([
        (ValueStructure.colorForm, .leaf(.color))
    ])

    static let stroke = ValueStructure.object(ObjectStructure(
        [
            ("color", .leaf(.color)),
            ("width", .leaf(.length(.positive))),
            ("join", .leaf(.name)),
            ("cap", .leaf(.name)),
            ("start", .leaf(.name)),
            ("end", .leaf(.name))
        ],
        required: ["width"],
        exclusive: [["color", "gradient"]]
    ))

    static let shadow = ValueStructure.object(ObjectStructure(
        [
            ("radius", .leaf(.length())),
            ("offset", .leaf(.lengths(count: 2))),
            ("color", .leaf(.color))
        ],
        shorthands: [.on]
    ))

    static let border = ValueStructure.object(ObjectStructure(
        [
            ("width", .leaf(.length(.positive))),
            ("color", .leaf(.color))
        ],
        shorthands: [.on, .color(key: "color")]
    ))

    static let length = ValueStructure.leaf(.length())

    static let textStroke = ValueStructure.object(ObjectStructure(
        [
            ("width", .leaf(.length(.positive))),
            ("color", .leaf(.color))
        ],
        required: ["width"]
    ))

    static let background = ValueStructure.object(ObjectStructure([
        ("color", .leaf(.color)),
        ("padding", .leaf(.lengths(count: 2, domain: .nonNegative))),
        ("radius", .leaf(.length()))
    ]))

    static let textStyle = ValueStructure.object(ObjectStructure([
        ("font", .list(.leaf(.name))),
        ("size", .leaf(.length(.positive))),
        ("weight", .leaf(.name)),
        ("color", .leaf(.color)),
        ("lineHeight", .leaf(.length(.positive))),
        ("stroke", textStroke),
        ("background", background),
        ("placement", .leaf(.name)),
        ("offset", .leaf(.length())),
        ("align", .leaf(.name)),
        ("lines", .leaf(.number(.positive)))
    ]))

    static let shapeStyle = ValueStructure.object(ObjectStructure([
        ("fill", fill),
        ("stroke", stroke),
        ("radius", length),
        ("outset", length),
        ("shadow", shadow)
    ]))

    static let transition = ValueStructure.choice(offNames: ["cut"])

    static let filter = ValueStructure.choice(offNames: ["none"])

    static let animation = ValueStructure.choice(offNames: ["none"])

    static let theme = ValueStructure.object(ObjectStructure([
        ("baseWidth", .leaf(.number(.positive))),
        ("font", .list(.leaf(.name))),
        ("colors", .map(.leaf(.color))),
        ("styles", .map(textStyle)),
        ("shapes", .map(shapeStyle)),
        ("placement", .object(ObjectStructure([("padding", length)]))),
        ("border", border),
        ("shadow", shadow),
        ("defaults", .object(ObjectStructure([
            ("transition", transition),
            ("filter", filter),
            ("animation", .object(ObjectStructure([
                ("title", .map(animation)),
                ("shape", animation),
                ("media", animation),
                ("adjust", animation)
            ])))
        ])))
    ]))
}
