//
//  ShapeKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The appearance keys a shape clip and a shape style share, `shadow` also a media clip's and a storyline clip's, and the
// shape style itself.
enum ShapeKeyTable {
    static let fill = ValueType.oneOf([.exactly(.bool(false)), .color])
    static let stroke = ValueType.oneOf([
        .exactly(.bool(false)),
        .object(ObjectTable(
            kind: "stroke",
            rules: [
                KeyRule("color", .color),
                KeyRule("width", .positiveNumber),
                KeyRule("join", .literal(StrokeJoin.allCases.map(\.rawValue))),
                KeyRule("cap", .literal(StrokeCap.allCases.map(\.rawValue))),
                KeyRule("start", .literal(StrokeEnd.allCases.map(\.rawValue))),
                KeyRule("end", .literal(StrokeEnd.allCases.map(\.rawValue))),
                KeyRule("dash", .dash),
                KeyRule("dashOffset", .number)
            ]
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
