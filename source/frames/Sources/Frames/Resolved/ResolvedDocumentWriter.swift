//
//  ResolvedDocumentWriter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Writes what resolve decided as the resolved document: JSON of the same kind as its document, `kind` first and
// `"resolved"` second, set to the version of this frames. The same plan and the same files give the same bytes.
struct ResolvedDocumentWriter: Sendable {
    // MARK: - Property
    private let sequences: SequenceWriter
    private let pictures: PictureWriter
    private let writer = JSONWriter()

    // MARK: - Initializer
    init(hashes: any FileHashProvider) {
        let values = ResolvedValueWriter(hashes: hashes)
        self.sequences = SequenceWriter(values: values)
        self.pictures = PictureWriter(values: values)
    }

    // MARK: - Public
    func write(_ plan: DocumentPlan) throws -> String {
        writer.write(try document(plan))
    }

    func document(_ plan: DocumentPlan) throws -> JSONValue {
        let kind: String
        let members: [JSONMember]
        switch plan {
        case let .sequence(sequence):
            kind = "sequence"
            members = try sequences.members(of: sequence)

        case let .picture(picture):
            kind = picture.kind
            members = try pictures.members(of: picture, sequences: sequences.members)
        }

        return .object(JSONObject(members: [
            JSONMember(key: "kind", value: .string(kind)),
            JSONMember(key: "resolved", value: .string(FramesVersion.current))
        ] + members))
    }

    // MARK: - Private
}
