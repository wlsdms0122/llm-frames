//
//  MediaFrame.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One frame of pinned media by its index in frame order. A still has the one frame 0.
package struct MediaFrame: Equatable, Sendable {
    // MARK: - Property
    package let media: PinnedMedia
    package let index: Int

    var file: PinnedFile {
        switch media.source {
        case let .file(file):
            file

        case let .imageSequence(files):
            files[index]
        }
    }

    // MARK: - Initializer
    package init(
        media: PinnedMedia,
        index: Int
    ) {
        self.media = media
        self.index = index
    }

    init(
        media: PinnedMedia,
        mediaTime: Double
    ) {
        self.init(media: media, index: media.frameIndex(at: mediaTime))
    }

    init(
        media: ResolvedTransitionMedia,
        progress: Double
    ) {
        self.init(media: media.media, mediaTime: progress * media.duration)
    }

    // MARK: - Public
    // MARK: - Private
}
