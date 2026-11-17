//
//  ResolvedDocumentWriter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Writes a resolved document as JSON, `kind` first and `"resolved"` second, set to the version of this frames. The same
// document gives the same bytes.
package struct ResolvedDocumentWriter: Sendable {
    // MARK: - Property
    private let sequences = ResolvedSequenceWriter()
    private let writer = JSONWriter()

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    package func write(_ sequence: ResolvedSequence) -> String {
        writer.write(document(sequence))
    }

    func document(_ sequence: ResolvedSequence) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "kind", value: .string("sequence")),
            JSONMember(key: "resolved", value: .string(FramesVersion.current))
        ] + sequences.members(of: sequence)))
    }

    // MARK: - Private
}
