//
//  DocumentThemeResolver.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Merges a document's own `theme` over the theme in effect where the document is written, for every document kind.
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
        let place = place.appending(key: "theme")

        switch reference {
        case nil:
            return theme

        case let .object(layer):
            return try merger.merge([ThemeLayer(value: layer, place: place, pack: library.pack)], over: theme)

        case let .named(name):
            guard let layer = try library.theme(named: name) else {
                throw ResolveError.unknownTheme(place: place, kind: kind, name: name)
            }

            return try merger.merge([layer], over: theme)
        }
    }

    // MARK: - Private
}
