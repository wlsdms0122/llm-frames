//
//  LocatedMedia.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Where a point of the output falls in a picture's media: the file the frame is read from, an image sequence's frame
// file for one, the media time of the frame drawn, the point in that frame's pixels, or in its points for a page of a
// PDF, nil where the picture shows the whole frame, whose size in pixels evaluation does not know, and the number of
// the page of a PDF the picture shows, nil for every other medium.
package struct LocatedMedia: Equatable, Sendable {
    // MARK: - Property
    package let file: String
    package let mediaTime: Double
    package let point: Point?
    package let page: Int?

    // MARK: - Initializer
    init(
        file: String,
        mediaTime: Double,
        point: Point?,
        page: Int? = nil
    ) {
        self.file = file
        self.mediaTime = mediaTime
        self.point = point
        self.page = page
    }

    // `point` is in output pixels.
    init(
        _ placement: MediaPlacement,
        point: Point
    ) {
        self.init(
            file: placement.frame.file.path,
            mediaTime: placement.mediaTime,
            point: placement.transform.map { $0.apply(to: point) },
            page: placement.frame.media.page
        )
    }

    // MARK: - Public
    // MARK: - Private
}
