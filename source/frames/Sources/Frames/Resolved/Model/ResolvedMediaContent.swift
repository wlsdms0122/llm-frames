//
//  ResolvedMediaContent.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a storyline entry or media clip shows: pinned media, or the nested resolved sequence of a compound clip, a
// template instance or a document named by its file, in place of a file.
enum ResolvedMediaContent: Equatable, Sendable {
    case pinned(PinnedMedia)
    case nested(ResolvedSequence)

    // MARK: - Property
    // The first and last media time a picture exists at: the pinned frame times, or a nested sequence held inside
    // `[0, duration)`. A still with no frame times simply goes on.
    var frames: ClosedRange<Double>? {
        switch self {
        case let .pinned(media):
            guard let first = media.frameTimes.first, let last = media.frameTimes.last else { return nil }

            return first...last

        case let .nested(sequence):
            return 0...(sequence.format.duration - .timeResolution)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
