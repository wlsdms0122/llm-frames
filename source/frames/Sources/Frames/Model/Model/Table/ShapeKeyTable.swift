//
//  ShapeKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The appearance keys a shape clip and a shape style share, `shadow` also a media clip's and a storyline clip's, and the
// shape style itself.
enum ShapeKeyTable {
    // A gradient's points and stops are required of the merged value, not here, so a clip may change one leaf of its
    // style's gradient.
    static let gradient = ValueType.object(ObjectTable(
        kind: "gradient",
        rules: [
            KeyRule("linear", .object(ObjectTable(
                kind: "linear gradient",
                rules: [
                    KeyRule("from", .numbers(2)),
                    KeyRule("to", .numbers(2)),
                    KeyRule("stops", .stops(isKeyframed: false))
                ]
            ))),
            KeyRule("radial", .object(ObjectTable(
                kind: "radial gradient",
                rules: [
                    KeyRule("center", .numbers(2)),
                    KeyRule("radius", .positiveNumber),
                    KeyRule("stops", .stops(isKeyframed: false))
                ]
            )))
        ],
        group: KeyGroup(keys: ["linear", "radial"], isExclusive: true)
    ))
    static let fill = ValueType.oneOf([.exactly(.bool(false)), .color, gradient])
    static let stroke = ValueType.oneOf([
        .exactly(.bool(false)),
        .object(ObjectTable(
            kind: "stroke",
            rules: [
                KeyRule("color", .color),
                KeyRule("gradient", gradient),
                KeyRule("width", .positiveNumber),
                KeyRule("join", .literal(StrokeJoin.allCases.map(\.rawValue))),
                KeyRule("cap", .literal(StrokeCap.allCases.map(\.rawValue))),
                KeyRule("start", .literal(StrokeEnd.allCases.map(\.rawValue))),
                KeyRule("end", .literal(StrokeEnd.allCases.map(\.rawValue))),
                KeyRule("dash", .dash),
                KeyRule("dashOffset", .number)
            ],
            group: KeyGroup(keys: ["color", "gradient"], isExclusive: true, isOptional: true)
        ))
    ])
    static let shadow = ValueType.oneOf([
        .bool,
        .object(ObjectTable(
            kind: "shadow",
            rules: [
                KeyRule("radius", .nonNegativeNumber),
                KeyRule("offset", .numbers(2)),
                KeyRule("color", .color)
            ]
        ))
    ])
    static let style = ObjectTable(
        kind: "shape style",
        rules: [
            KeyRule("fill", fill),
            KeyRule("stroke", stroke),
            KeyRule("radius", .nonNegativeNumber),
            KeyRule("outset", .nonNegativeNumber),
            KeyRule("shadow", shadow)
        ]
    )
}
