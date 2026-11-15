//
//  ChoiceKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ChoiceKeyTable {
    static let transition = ValueType.oneOf([
        .name,
        .object(ObjectTable(
            kind: "transition choice",
            rules: [
                KeyRule("preset", .name, isRequired: true),
                KeyRule("seconds", .number, isRequired: true)
            ]
        ))
    ])
    static let animation = ValueType.oneOf([
        .name,
        .object(ObjectTable(
            kind: "animation choice",
            rules: [
                KeyRule("entrance", .name, isRequired: true),
                KeyRule("exit", .name, isRequired: true)
            ]
        ))
    ])
    static let filter = ValueType.oneOf([.name, .list(.name)])
}
