//
//  EaseKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

enum EaseKeyTable {
    static let spring = ObjectTable(
        kind: "spring ease",
        rules: [KeyRule("spring", .object(bounce), isRequired: true)]
    )

    private static let bounce = ObjectTable(
        kind: "spring",
        rules: [KeyRule("bounce", .number(.between(-1, 1)), isRequired: true)]
    )
}
