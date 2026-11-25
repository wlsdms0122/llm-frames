//
//  MediaFile+ProbedMedia.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

extension MediaFile {
    // MARK: - Property
    // MARK: - Initializer
    // A file of media that is no page, by its probed kind. A decoder's probe of a file gives an image, a video or
    // sound; `ProbedMedia.kind` also holds a sequence and a page, which are read as a video by their frames and as a
    // still. An image sequence is `ImageSequence`'s, and a page is made with its number from the probe of the page.
    init(
        path: String,
        probed: ProbedMedia
    ) {
        let colorReading = probed.colorSpace?.reading
        let kind: MediaFileKind = switch probed.kind {
        case .video, .sequence:
            .video(frameTimes: probed.frames, fps: probed.fps, size: probed.size, colorReading: colorReading)

        case .image, .page:
            .still(size: probed.size, colorReading: colorReading)

        case .audio:
            .sound
        }
        self.init(path: path, kind: kind)
    }

    // MARK: - Public
    // MARK: - Private
}
