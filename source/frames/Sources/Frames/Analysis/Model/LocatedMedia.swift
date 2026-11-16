//
//  LocatedMedia.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Where a point of the output falls in a picture's media: the file the frame is read from, an image sequence's frame
// file for one, the media time of the frame drawn, and the point in that frame's pixels, nil where the picture shows
// the whole frame, whose size in pixels evaluation does not know.
package struct LocatedMedia: Equatable, Sendable {
    // MARK: - Property
    package let file: String
    package let mediaTime: Double
    package let point: Point?

    // MARK: - Initializer
    init(
        file: String,
        mediaTime: Double,
        point: Point?
    ) {
        self.file = file
        self.mediaTime = mediaTime
        self.point = point
    }

    // `point` is in output pixels.
    init(
        _ placement: MediaPlacement,
        point: Point
    ) {
        self.init(
            file: placement.frame.file.path,
            mediaTime: placement.mediaTime,
            point: placement.transform.map { $0.apply(to: point) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
