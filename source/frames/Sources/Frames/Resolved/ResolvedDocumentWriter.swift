//
//  ResolvedDocumentWriter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Writes a resolved document as JSON of the same kind as its document, `kind` first and `"resolved"` second, set to
// the version of this frames. The same document gives the same bytes.
struct ResolvedDocumentWriter: Sendable {
    // MARK: - Property
    private let sequences = ResolvedSequenceWriter()
    private let pictures = ResolvedPictureWriter()
    private let writer = JSONWriter()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func write(_ document: ResolvedDocument) -> String {
        writer.write(self.document(document))
    }

    func document(_ document: ResolvedDocument) -> JSONValue {
        let kind: String
        let members: [JSONMember]
        switch document {
        case let .sequence(sequence):
            kind = "sequence"
            members = sequences.members(of: sequence)

        case let .picture(picture):
            kind = picture.kind
            members = pictures.members(of: picture, sequences: sequences.members)
        }

        return .object(JSONObject(members: [
            JSONMember(key: "kind", value: .string(kind)),
            JSONMember(key: "resolved", value: .string(FramesVersion.current))
        ] + members))
    }

    // MARK: - Private
}
