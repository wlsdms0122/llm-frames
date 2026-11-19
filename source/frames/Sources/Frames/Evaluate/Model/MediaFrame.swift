//
//  MediaFrame.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One frame of pinned media by its index in frame order, and how the decoder reads its picture: `colorSpace` is the
// space that overrides the file's tags, nil where they apply, and `targetPeak` the peak in cd/m² an HDR picture of it
// is tone mapped to, nil where it is taken as display light. A still has the one frame 0. A transition matte's frame
// carries no target peak, since it is read as an analysis picture.
package struct MediaFrame: Equatable, Sendable {
    // MARK: - Property
    package let media: PinnedMedia
    package let index: Int
    package let colorSpace: ColorSpace?
    package let targetPeak: Double?

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
        index: Int,
        colorSpace: ColorSpace? = nil,
        targetPeak: Double? = nil
    ) {
        self.media = media
        self.index = index
        self.colorSpace = colorSpace
        self.targetPeak = targetPeak
    }

    init(
        media: PinnedMedia,
        mediaTime: Double,
        colorSpace: ColorSpace? = nil,
        targetPeak: Double? = nil
    ) {
        self.init(media: media, index: media.frameIndex(at: mediaTime), colorSpace: colorSpace, targetPeak: targetPeak)
    }

    init(
        media: ResolvedTransitionMedia,
        progress: Double,
        targetPeak: Double? = nil
    ) {
        self.init(
            media: media.media,
            mediaTime: progress * media.duration,
            colorSpace: media.colorSpace,
            targetPeak: targetPeak
        )
    }

    // MARK: - Public
    // MARK: - Private
}
