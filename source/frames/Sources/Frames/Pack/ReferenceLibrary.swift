//
//  ReferenceLibrary.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Reads what a document names by `<pack>/<name>` or an absolute path: themes, templates, documents used as media and
// media files. A file read here is checked where it is read, and its errors name it as it was referred to.
// `reading` holds the files and template instances being read on the way here, so a document or an instance that
// holds itself stops instead of never ending.
struct ReferenceLibrary: MediaKindProvider {
    // MARK: - Property
    private let packs: PackLibrary
    private let mediaFacts: any MediaFactProvider
    private let reading: [ReadingEntry]

    // MARK: - Initializer
    init(
        packs: PackLibrary,
        mediaFacts: any MediaFactProvider
    ) {
        self.init(packs: packs, mediaFacts: mediaFacts, reading: [])
    }

    private init(
        packs: PackLibrary,
        mediaFacts: any MediaFactProvider,
        reading: [ReadingEntry]
    ) {
        self.packs = packs
        self.mediaFacts = mediaFacts
        self.reading = reading
    }

    // MARK: - Lifecycle
    // A document's kind is the kind of document it is, and a media file's is the one its probe finds.
    func mediaKind(of reference: String) throws -> MediaKind? {
        guard !isDocument(reference) else { return try document(named: reference)?.kind }
        guard let file = try mediaFile(named: reference) else { return nil }

        return mediaFacts.probedMedia(of: file)?.kind
    }

    func templateKind(of name: String) throws -> MediaKind? {
        try template(named: name)?.kind
    }

    // MARK: - Public
    // A theme is `<pack>/<name>` or an absolute path, so a bare name names none.
    func theme(named name: String) throws -> ThemeLayer? {
        guard let value = try value(named: name, in: "themes", pathExtension: "json")?.value else { return nil }

        return ThemeLayer(value: value, place: Place(file: name, components: []))
    }

    func template(named name: String) throws -> Template? {
        guard let (file, value) = try value(named: name, in: "templates", pathExtension: "json") else { return nil }

        return try TemplateReader(mediaKinds: reading(file: file, name: name))
            .template(from: value, place: Place(file: name, components: []))
    }

    // A document used as media is a `.json` file, by path or in a pack's `media/`.
    func document(named reference: String) throws -> DocumentFile? {
        guard let (file, value) = try value(named: reference, in: "media", pathExtension: nil) else { return nil }

        try KeyChecker(mediaKinds: reading(file: file, name: reference))
            .check(nestedDocument: value, place: Place(file: reference, components: []))
        return DocumentFile(name: reference, file: file, value: value, kind: MediaKind(document: value))
    }

    func isDocument(_ reference: String) -> Bool {
        URL(fileURLWithPath: reference).pathExtension.lowercased() == "json"
    }

    // The file or directory a media reference names: a path as it is, and `<pack>/<name.ext>` or `<pack>/<dir>` in
    // the pack's `media/`. There is no built in media.
    func mediaFile(named reference: String) throws -> String? {
        guard let reference = PackReference(reference) else { return nil }

        return try packs.file(of: reference, in: "media", pathExtension: nil)?.path
    }

    // The library to read what a file names with, once the file is being read.
    func reading(
        file: String,
        name: String
    ) throws -> ReferenceLibrary {
        try reading(ReadingEntry(name: file, values: nil), name: name)
    }

    // The library to plan an instance of the template `name` with, once `values` are given to its parameters.
    func reading(
        instanceOf name: String,
        values: [String: JSONValue]
    ) throws -> ReferenceLibrary {
        try reading(ReadingEntry(name: name, values: values), name: name)
    }

    // MARK: - Private
    private func reading(
        _ entry: ReadingEntry,
        name: String
    ) throws -> ReferenceLibrary {
        if let start = reading.firstIndex(of: entry) {
            throw PackError.circularReference(
                place: Place(file: name, components: []),
                files: (reading[start...] + [entry]).map(\.name)
            )
        }

        return ReferenceLibrary(packs: packs, mediaFacts: mediaFacts, reading: reading + [entry])
    }

    private func value(
        named name: String,
        in folder: String,
        pathExtension: String?
    ) throws -> (file: String, value: JSONValue)? {
        guard let reference = PackReference(name) else { return nil }
        guard let file = try packs.file(of: reference, in: folder, pathExtension: pathExtension) else { return nil }
        guard let data = try packs.contents(of: file) else { return nil }

        return (file.path, try JSONReader(file: name).read(data))
    }
}
