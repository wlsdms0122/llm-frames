//
//  DisplacementMapRefusal.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// What a `displace` op's file is when it is no raster still read as its tags say: a video, an image sequence's
// directory, a PDF, whose pages are no raster, a sequence document, sound, or a picture whose colour no fixed formula
// converts (FRAMES-26 Media), since a map takes no `colorSpace`.
enum DisplacementMapRefusal: Equatable, Sendable {
    case video
    case imageSequence
    case page
    case sequence
    case sound
    case unconvertibleColor

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
