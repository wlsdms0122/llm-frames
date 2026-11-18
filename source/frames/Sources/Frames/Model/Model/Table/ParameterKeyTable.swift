//
//  ParameterKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The one parameter object of templates and presets, with the limits each owner sets on it.
enum ParameterKeyTable {
    static let kind = "parameter"
    static let template = ObjectTable(
        kind: kind,
        rules: [
            KeyRule("type", .literal(VocabularyTable.parameterTypes), isRequired: true),
            KeyRule("default", .anyValue),
            KeyRule("description", .text),
            KeyRule("options", .list(.anyValue))
        ]
    )
}
