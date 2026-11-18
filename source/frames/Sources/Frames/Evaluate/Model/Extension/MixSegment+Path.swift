//
//  MixSegment+Path.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// A media file heard along a path. The envelope has a point at both ends, at every breakpoint of every layer and at
// every frame time `k / fps` between them, each the exact product of the gains at its time, so straight lines stand in
// for eased volume at the frame rate and a single linear ramp is exact.
extension MixSegment {
    // MARK: - Property
    // MARK: - Initializer
    init(
        media: PinnedMedia,
        path: MixPath,
        fps: Double
    ) {
        let start = path.heard.start
        let end = path.heard.end
        let frames = stride(from: Int(ceil(start * fps)), through: Int(floor(end * fps)), by: 1)
        let inside = (path.layers.flatMap(\.breakpoints) + frames.map { Double($0) / fps })
            .filter { start < $0 && $0 < end }
        let times = [start] + Set(inside).sorted() + [end]

        self.init(
            media: media,
            mediaStart: path.clock.clipTime(atSequenceTime: start),
            speed: path.clock.speed,
            start: start,
            end: end,
            envelope: times.map { EnvelopePoint(time: $0, value: path.gain(at: $0)) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
