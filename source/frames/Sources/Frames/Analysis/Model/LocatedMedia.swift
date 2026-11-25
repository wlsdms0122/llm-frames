//
//  LocatedMedia.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Where a point of the output falls in a picture's media: the frame the picture draws, and the point in that frame's
// pixels, or in its points for a page of a PDF, nil where the picture shows the whole frame, whose size in pixels
// evaluation does not know.
package struct LocatedMedia: Equatable, Sendable {
    // MARK: - Property
    package let frame: DrawnFrame
    package let point: Point?

    package var file: String {
        frame.file
    }

    package var mediaTime: Double {
        frame.mediaTime
    }

    package var page: Int? {
        frame.page
    }

    // MARK: - Initializer
    init(
        frame: DrawnFrame,
        point: Point?
    ) {
        self.frame = frame
        self.point = point
    }

    init(
        file: String,
        mediaTime: Double,
        point: Point?,
        page: Int? = nil
    ) {
        self.init(frame: DrawnFrame(file: file, mediaTime: mediaTime, page: page), point: point)
    }

    // `point` is in output pixels.
    init(
        _ placement: MediaPlacement,
        point: Point
    ) {
        self.init(frame: DrawnFrame(placement), point: placement.transform.flatMap { $0.apply(to: point) })
    }

    // MARK: - Public
    // MARK: - Private
}
