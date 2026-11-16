//
//  ResolvedDocumentReader.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Reads a resolved document from its JSON text into the model evaluation reads. Its version is checked before anything
// else, so a document this frames cannot read stops naming both versions. It reads only what resolve writes: a member
// that is missing or of another type, or a key resolve never writes there, stops naming its place. It does not check
// resolve's rules again, since the document was resolved.
struct ResolvedDocumentReader: Sendable {
    // MARK: - Property
    private let checker: ResolvedDocumentChecker
    private let sequences = ResolvedSequenceReader()

    // MARK: - Initializer
    init(checker: ResolvedDocumentChecker = ResolvedDocumentChecker()) {
        self.checker = checker
    }

    // MARK: - Public
    func read(_ text: String) throws -> ResolvedDocument {
        try read(JSONReader().read(text))
    }

    func read(_ value: JSONValue) throws -> ResolvedDocument {
        let root = PlacedJSONValue(value, place: .root, kind: "resolved document")
        guard let object = value.objectValue else { throw root.wrongType("an object") }
        guard try checker.version(of: value, theme: nil, arguments: nil) != nil else {
            throw ModelError.missingKey(place: .root, kind: object["kind"]?.stringValue ?? root.kind, keys: ["resolved"])
        }

        return try sequences.document(root, extraKeys: ["resolved"])
    }

    // MARK: - Private
}
