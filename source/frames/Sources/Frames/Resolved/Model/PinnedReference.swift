//
//  PinnedReference.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Something a resolved document pins for a role to open: media, which the decoder reads, or a single file, a font or a
// LUT. `place` is the entry that names it, or for what an image or layout's steps name, the clip that holds that
// picture, nil at the top level.
enum PinnedReference: Equatable, Sendable {
    case media(PinnedMedia, place: String?)
    case file(PinnedFile, place: String?)

    // MARK: - Property
    var place: String? {
        switch self {
        case let .media(_, place), let .file(_, place):
            place
        }
    }

    // Every file it pins, an image sequence's frame files in frame order.
    var files: [PinnedFile] {
        switch self {
        case let .media(media, _):
            switch media.source {
            case let .file(file):
                [file]

            case let .imageSequence(files):
                files
            }

        case let .file(file, _):
            [file]
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
