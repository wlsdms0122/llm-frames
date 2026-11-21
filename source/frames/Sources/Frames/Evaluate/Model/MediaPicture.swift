//
//  MediaPicture.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// Which picture of its media a media frame is (a coined name): a frame of a video, an image sequence or an image by
// its index in frame order, an image having the one frame 0, or the page of a PDF its media names, which the decoder
// reads by a region at a scale the renderer chooses (FRAMES-20 Pictures).
package enum MediaPicture: Equatable, Hashable, Sendable {
    case frame(Int)
    case page

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
