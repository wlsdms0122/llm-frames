//
//  PackKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum PackKeyTable {
    static let manifest = ObjectTable(
        kind: "manifest",
        rules: [
            KeyRule("engine", .text, isRequired: true),
            KeyRule("name", .text),
            KeyRule("version", .text),
            KeyRule("description", .text)
        ]
    )
    static let tool = ObjectTable(
        kind: "tool",
        rules: [
            KeyRule("description", .text, isRequired: true),
            KeyRule("run", .text, isRequired: true)
        ]
    )
}
