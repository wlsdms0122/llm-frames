//
//  MixSegment.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A stretch of one media file heard in the output, from sequence time `start` to `end`, playing from media time
// `mediaStart`. Pans run from -1 (left) to 1 (right). Both envelopes' points are in sequence time from `start` to
// `end`, joined in straight lines.
package struct MixSegment: Equatable, Sendable {
    // MARK: - Property
    package let media: PinnedMedia
    package let mediaStart: Double
    package let speed: Double
    package let start: Double
    package let end: Double
    package let envelope: [EnvelopePoint]
    package let pan: [EnvelopePoint]

    // MARK: - Initializer
    package init(
        media: PinnedMedia,
        mediaStart: Double,
        speed: Double,
        start: Double,
        end: Double,
        envelope: [EnvelopePoint],
        pan: [EnvelopePoint]
    ) {
        self.media = media
        self.mediaStart = mediaStart
        self.speed = speed
        self.start = start
        self.end = end
        self.envelope = envelope
        self.pan = pan
    }

    // MARK: - Public
    // MARK: - Private
}
