//
//  MediaKindTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The probed kind of each media file and template, keyed by the reference written in the document.
struct MediaKindTable: MediaKindProvider {
    // MARK: - Property
    let kinds: [String: MediaKind]

    // MARK: - Initializer
    init(_ kinds: [String: MediaKind] = [:]) {
        self.kinds = kinds
    }

    // MARK: - Public
    func mediaKind(of reference: String) -> MediaKind? {
        kinds[reference]
    }

    // MARK: - Private
}
