//
//  MixSegment.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A stretch of one media file heard in the output: from sequence time `start` to `end`, playing from media time
// `mediaStart` at `speed`, at the gain its envelope gives. The envelope's points are in sequence time from `start` to
// `end`, joined in straight lines.
struct MixSegment: Equatable, Sendable {
    // MARK: - Property
    let media: PinnedMedia
    let mediaStart: Double
    let speed: Double
    let start: Double
    let end: Double
    let envelope: [EnvelopePoint]

    // MARK: - Initializer
    init(
        media: PinnedMedia,
        mediaStart: Double,
        speed: Double,
        start: Double,
        end: Double,
        envelope: [EnvelopePoint]
    ) {
        self.media = media
        self.mediaStart = mediaStart
        self.speed = speed
        self.start = start
        self.end = end
        self.envelope = envelope
    }

    // MARK: - Public
    // MARK: - Private
}
