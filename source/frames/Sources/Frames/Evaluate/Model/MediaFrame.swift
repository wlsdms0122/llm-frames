//
//  MediaFrame.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One picture of pinned media, a frame by its index in frame order or a page of a PDF, and how the decoder reads it: as
// working values, in the colour space written where the media is named and tone mapped to the target peak, or as an
// analysis picture, as a transition matte and a frame a command shows are read. A page has no target peak, since a
// page is not HDR.
package struct MediaFrame: Equatable, Sendable {
    // MARK: - Property
    package let media: PinnedMedia
    package let picture: MediaPicture
    package let reading: PictureReading

    var file: PinnedFile {
        switch media.source {
        case let .file(file, _), let .page(file, _):
            file

        case let .imageSequence(files, _):
            if case let .frame(index) = picture { files[index] } else { files[0] }
        }
    }

    // MARK: - Initializer
    // A page of a PDF is its page, whatever `index` is.
    package init(
        media: PinnedMedia,
        index: Int,
        reading: PictureReading = .tagged
    ) {
        self.media = media
        guard media.page != nil else {
            self.picture = .frame(index)
            self.reading = reading
            return
        }

        self.picture = .page
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
