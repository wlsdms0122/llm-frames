//
//  MediaKindTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The probed kind of each media file, keyed by the reference written in the document, and the names of the templates
// that are there.
struct MediaKindTable: MediaKindProvider {
    // MARK: - Property
    let kinds: [String: MediaKind]
    let templates: Set<String>

    // MARK: - Initializer
    init(
        _ kinds: [String: MediaKind] = [:],
        templates: Set<String> = []
    ) {
        self.kinds = kinds
        self.templates = templates
    }

    // MARK: - Public
    func mediaKind(of reference: String) -> MediaKind? {
        kinds[reference]
    }

    func hasTemplate(named name: String) -> Bool {
        templates.contains(name)
    }

    // MARK: - Private
}
