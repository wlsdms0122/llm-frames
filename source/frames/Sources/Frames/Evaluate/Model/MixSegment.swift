//
//  MixSegment.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A stretch of one media file heard in the output: from sequence time `start` to `end`, playing from media time
// `mediaStart` at `speed`, at the gain its envelope gives. The envelope's points are in sequence time from `start` to
// `end`, joined in straight lines.
package struct MixSegment: Equatable, Sendable {
    // MARK: - Property
    package let media: PinnedMedia
    package let mediaStart: Double
    package let speed: Double
    package let start: Double
    package let end: Double
    package let envelope: [EnvelopePoint]

    // MARK: - Initializer
    package init(
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
