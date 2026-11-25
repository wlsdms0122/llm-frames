//
//  EaseKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// An ease written as an object, which names its ease with `kind`. A spring is the one such ease.
enum EaseKeyTable {
    static let spring = ObjectTable(
        kind: "ease",
        rules: [
            KeyRule("kind", .literal(["spring"]), isRequired: true),
            KeyRule("bounce", .number(.between(-1, 1)), isRequired: true)
        ]
    )
}
