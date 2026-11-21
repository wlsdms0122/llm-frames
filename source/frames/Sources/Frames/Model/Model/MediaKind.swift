//
//  MediaKind.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The kinds of media: a video or an image sequence, a compound clip, an image, a page of a PDF, a sound.
package enum MediaKind: String, CaseIterable, Sendable {
    case video
    case sequence
    case image
    case page
    case audio

    // MARK: - Property
    // A still is a picture without time: an image or a page of a PDF.
    var isStill: Bool {
        self == .image || self == .page
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
