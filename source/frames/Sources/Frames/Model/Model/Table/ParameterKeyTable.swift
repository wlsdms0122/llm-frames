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
    // A preset holds no text and no media, and is named without arguments, so its parameters are values with a
    // default, and a choice picks an ease.
    static let preset = ObjectTable(
        kind: kind,
        rules: [
            KeyRule("type", .literal(["number", "color", "choice"]), isRequired: true),
            KeyRule("default", .anyValue, isRequired: true),
            KeyRule("description", .text),
            KeyRule("options", .list(.ease))
        ]
    )
    // A filter has no ease, so it has no choice.
    static let filterPreset = ObjectTable(
        kind: kind,
        rules: [
            KeyRule("type", .literal(["number", "color"]), isRequired: true),
            KeyRule("default", .anyValue, isRequired: true),
            KeyRule("description", .text)
        ]
    )
}
