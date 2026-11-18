//
//  MediaKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The forms media is written in where a document takes it: a reference string, or an object holding one of `keys`,
// a document, an image sequence or a template instance.
enum MediaKeyTable {
    static let imageSequence = ObjectTable(
        kind: "image sequence",
        rules: [
            KeyRule("imageSequence", .name, isRequired: true),
            KeyRule("fps", .positiveNumber, isRequired: true)
        ]
    )
    // An object holding none of them is a value, such as a choice's `{preset, args}` or an ease.
    static let keys = ["kind", "imageSequence", "template"]

    static func isMedia(_ value: JSONValue) -> Bool {
        guard let object = value.objectValue else { return false }

        return keys.contains(where: object.contains)
    }
}
