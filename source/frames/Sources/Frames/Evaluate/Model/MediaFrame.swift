//
//  MediaFrame.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One frame of pinned media by its index in frame order, and how the decoder reads its picture: as working values, in
// the colour space written where the media is named and tone mapped to the target peak, or as an analysis picture, as
// a transition matte and a frame a command shows are read. An image has the one frame 0. A page of a PDF has no index,
// since the decoder reads it by a region at a scale the renderer chooses (FRAMES-20 Pictures), and no target peak,
// since a page is not HDR.
package struct MediaFrame: Equatable, Sendable {
    // MARK: - Property
    package let media: PinnedMedia
    package let index: Int?
    package let reading: PictureReading

    var file: PinnedFile {
        switch media.source {
        case let .file(file), let .page(file, _):
            file

        case let .imageSequence(files):
            files[index ?? 0]
        }
    }

    // MARK: - Initializer
    // `index` is ignored for a page.
    package init(
        media: PinnedMedia,
        index: Int,
        reading: PictureReading = .tagged
    ) {
        self.media = media
        guard media.page != nil else {
            self.index = index
            self.reading = reading
            return
        }

        self.index = nil
        self.reading = if case let .working(colorSpace, _) = reading {
            .working(colorSpace: colorSpace, targetPeak: nil)
        } else {
            reading
        }
    }

    init(
        media: PinnedMedia,
        mediaTime: Double,
        reading: PictureReading = .tagged
    ) {
        self.init(media: media, index: media.frameIndex(at: mediaTime), reading: reading)
    }

    // A transition's cover or matte at `progress` through the transition.
    init(
        media: ResolvedTransitionMedia,
        progress: Double,
        reading: PictureReading
    ) {
        self.init(media: media.media, mediaTime: progress * media.duration, reading: reading)
    }

    // MARK: - Public
    // MARK: - Private
}
