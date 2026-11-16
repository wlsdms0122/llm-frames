//
//  MediaFrame.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One frame of pinned media by its index in frame order. A still has the one frame 0.
struct MediaFrame: Equatable, Sendable {
    // MARK: - Property
    let media: PinnedMedia
    let index: Int

    // The file the frame is read from: the media file itself, or an image sequence's file at the index.
    var file: PinnedFile {
        switch media.source {
        case let .file(file):
            file

        case let .imageSequence(files):
            files[index]
        }
    }

    // MARK: - Initializer
    init(
        media: PinnedMedia,
        index: Int
    ) {
        self.media = media
        self.index = index
    }

    // The frame shown at the media time, as the media's pinned frame times pick it.
    init(
        media: PinnedMedia,
        mediaTime: Double
    ) {
        self.init(media: media, index: media.frameIndex(at: mediaTime))
    }

    // The frame a transition's cover or matte shows at a progress through it: media time progress x its duration, so
    // a still shows its one frame.
    init(
        media: ResolvedTransitionMedia,
        progress: Double
    ) {
        self.init(media: media.media, mediaTime: progress * media.duration)
    }

    // MARK: - Public
    // MARK: - Private
}
