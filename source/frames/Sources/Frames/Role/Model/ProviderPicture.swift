//
//  ProviderPicture.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The frame a provider was reading: its media, as the document or the command names it, and its media time in seconds.
struct ProviderPicture: Equatable, Sendable {
    // MARK: - Property
    let media: String
    let mediaTime: Double

    // MARK: - Initializer
    init(
        media: String,
        mediaTime: Double
    ) {
        self.media = media
        self.mediaTime = mediaTime
    }

    // MARK: - Public
    // MARK: - Private
}
