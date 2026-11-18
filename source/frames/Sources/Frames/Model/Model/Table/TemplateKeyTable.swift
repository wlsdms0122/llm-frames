//
//  TemplateKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum TemplateKeyTable {
    // A map's kind is not readable from its value type, so it is named on its own.
    static let argumentsKind = "template arguments"
    static let arguments = ValueType.map(.argument, kind: argumentsKind)
    static let instance = ObjectTable(
        kind: "template instance",
        rules: [
            KeyRule("template", .name, isRequired: true),
            KeyRule("args", arguments)
        ]
    )
    static let imageSequence = ObjectTable(
        kind: "image sequence",
        rules: [
            KeyRule("imageSequence", .name, isRequired: true),
            KeyRule("fps", .positiveNumber, isRequired: true)
        ]
    )
}
