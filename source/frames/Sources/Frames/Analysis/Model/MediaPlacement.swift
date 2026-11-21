//
//  MediaPlacement.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Where a frame of media is drawn: the frame, and the transform from output pixels into its pixels through every
// transform and nested list that holds it and the source rect it shows. The transform is nil where the picture shows
// the whole frame, whose size in pixels evaluation does not know, or covers nothing.
struct MediaPlacement: Equatable, Sendable {
    // MARK: - Property
    let frame: MediaFrame
    let transform: AffineTransform?

    // The media time of the frame drawn: its pinned time, or 0 for a still.
    var mediaTime: Double {
        let times = frame.media.frameTimes
        guard let index = frame.index, times.indices.contains(index) else { return 0 }

        return times[index]
    }

    // MARK: - Initializer
    init(
        frame: MediaFrame,
        transform: AffineTransform?
    ) {
        self.frame = frame
        self.transform = transform
    }

    // MARK: - Public
    // MARK: - Private
}
