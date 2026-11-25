//
//  DrawnFrame.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The frame a picture of a media file draws, as `evaluate` and `locate` give it (FRAMES-23): the pinned file it is
// read from, an image sequence's frame file for one, the frame's pinned media time, 0 for an image and a page, which
// have one picture, and the number of the page of a PDF it shows, nil for every other medium.
package struct DrawnFrame: Equatable, Sendable {
    // MARK: - Property
    package let file: String
    package let mediaTime: Double
    package let page: Int?

    // MARK: - Initializer
    init(
        file: String,
        mediaTime: Double,
        page: Int? = nil
    ) {
        self.file = file
        self.mediaTime = mediaTime
        self.page = page
    }

    init(_ placement: MediaPlacement) {
        self.init(
            file: placement.frame.file.path,
            mediaTime: placement.mediaTime,
            page: placement.frame.media.page
        )
    }

    // MARK: - Public
    // MARK: - Private
}
