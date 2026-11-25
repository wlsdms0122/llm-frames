//
//  MediaKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The forms media is written in where a document takes it: a reference string, or an object whose `kind` says what it
// is, a document, a page of a PDF, an image sequence or a template instance.
enum MediaKeyTable {
    // No object of the format but media writes one of these kinds, so an argument object that names one is media and
    // any other is a value, such as a choice's `{preset, args}` or an ease.
    static let kinds = [DocumentKeyTable.sequence.kind, "page", "imageSequence", "template"]
    static let page = ObjectTable(
        kind: "page",
        rules: [
            kindRule("page"),
            KeyRule("file", .name, isRequired: true),
            KeyRule("page", .positiveInteger, isRequired: true)
        ]
    )
    static let imageSequence = ObjectTable(
        kind: "image sequence",
        rules: [
            kindRule("imageSequence"),
            KeyRule("directory", .name, isRequired: true),
            KeyRule("fps", .number(.positive), isRequired: true)
        ]
    )
    // Media that names a file, as a transition's cover and matte take it: a name, or a page of a PDF (FRAMES-14).
    static let file = ValueType.oneOf([.name, .kinds(KindTable(kind: "media", tables: ["page": page]))])

    static func isMedia(_ value: JSONValue) -> Bool {
        guard let kind = value.objectValue?["kind"]?.stringValue else { return false }

        return kinds.contains(kind)
    }

    private static func kindRule(_ name: String) -> KeyRule {
        KeyRule("kind", .literal([name]), isRequired: true)
    }
}
