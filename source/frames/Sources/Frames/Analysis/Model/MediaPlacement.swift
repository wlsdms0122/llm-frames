//
//  MediaPlacement.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Where a frame of media is drawn: the frame, and the map from output pixels into its pixels back through every
// transform, corner pin and nested list that holds it and the source rect it shows. The map is nil where the picture
// shows the whole frame, whose size in pixels evaluation does not know, or covers nothing.
struct MediaPlacement: Equatable, Sendable {
    // MARK: - Property
    let frame: MediaFrame
    let transform: Homography?

    // The media time of the frame drawn: its pinned time, or 0 for a still.
    var mediaTime: Double {
        guard
            case let .frame(index) = frame.picture,
            let times = frame.media.frameTimes,
            times.indices.contains(index)
        else {
            return 0
        }

        return times[index]
    }

    // MARK: - Initializer
    init(
        frame: MediaFrame,
        transform: Homography?
    ) {
        self.frame = frame
        self.transform = transform
    }

    // MARK: - Public
    // MARK: - Private
}
