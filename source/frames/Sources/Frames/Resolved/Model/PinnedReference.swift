//
//  PinnedReference.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Something a resolved document pins for a role to open: media whose pictures the decoder reads, a displacement map
// among them, in the `colorSpace` written where it is named or as its tags say where that is nil, media only its sound
// is read from, an impulse response among them, or a single file, a font or a LUT. `place` is the entry that names
// it.
enum PinnedReference: Equatable, Sendable {
    case media(PinnedMedia, place: String, colorSpace: ColorSpace?)
    case sound(PinnedMedia, place: String)
    case file(PinnedFile, place: String)

    // MARK: - Property
    var place: String {
        switch self {
        case let .media(_, place, _), let .sound(_, place), let .file(_, place):
            place
        }
    }

    // Every file it pins, an image sequence's frame files in frame order.
    var files: [PinnedFile] {
        switch self {
        case let .media(media, _, _), let .sound(media, _):
            switch media.source {
            case let .file(file, _):
                [file]

            case let .imageSequence(files, _):
                files

            case let .page(file, _):
                [file]
            }

        case let .file(file, _):
            [file]
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
