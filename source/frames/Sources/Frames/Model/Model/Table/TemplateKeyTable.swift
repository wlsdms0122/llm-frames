//
//  TemplateKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum TemplateKeyTable {
    static let instance = ObjectTable(
        kind: "template instance",
        rules: [
            KeyRule("template", .name, isRequired: true),
            KeyRule("args", .map(.argument, kind: "template arguments"))
        ]
    )
    static let parameter = ObjectTable(
        kind: "parameter",
        rules: [
            KeyRule("type", .literal(VocabularyTable.parameterTypes), isRequired: true),
            KeyRule("default", .anyValue),
            KeyRule("description", .text),
            KeyRule("options", .list(.text))
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
