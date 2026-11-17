//
//  MediaKindTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The probed kind of each media file, and the templates that are there, keyed by the reference written in the
// document. A template is a sequence.
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

    func hasTemplate(named name: String) -> Bool {
        kinds[name] == .sequence
    }

    // MARK: - Private
}
