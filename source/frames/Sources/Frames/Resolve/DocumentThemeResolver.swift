//
//  DocumentThemeResolver.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Merges a document's own `theme` over the theme in effect where the document is written.
struct DocumentThemeResolver: Sendable {
    // MARK: - Property
    private let library: ReferenceLibrary
    private let merger = ThemeMerger()

    // MARK: - Initializer
    init(library: ReferenceLibrary) {
        self.library = library
    }

    // MARK: - Public
    // `place` is the document's, and `kind` what a stop names there.
    func theme(
        _ reference: ThemeReference?,
        of place: Place,
        kind: PlaceKind,
        over theme: MergedTheme
    ) throws -> MergedTheme {
        guard let merged = try self.theme(reference, of: place, over: theme) else {
            // Only a named theme can be missing.
            throw ResolveError.unknownTheme(
                place: place.appending(key: "theme"),
                kind: kind,
                name: reference?.name ?? ""
            )
        }

        return merged
    }

    // Nil where the reference names a theme that is not there.
    func theme(
        _ reference: ThemeReference?,
        of place: Place,
        over theme: MergedTheme
    ) throws -> MergedTheme? {
        switch reference {
        case nil:
            return theme

        case let .object(layer):
            let layer = ThemeLayer(value: layer, place: place.appending(key: "theme"), pack: library.pack)

            return try merger.merge([layer], over: theme)

        case let .named(name):
            guard let layer = try library.theme(named: name) else { return nil }

            return try merger.merge([layer], over: theme)
        }
    }

    // MARK: - Private
}
