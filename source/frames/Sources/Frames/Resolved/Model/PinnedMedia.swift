//
//  PinnedMedia.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Media as the resolved document pins it: its files, and the media time of each frame of a video or image sequence in
// frame order, empty for a still and for sound.
package struct PinnedMedia: Equatable, Sendable {
    // MARK: - Property
    package let source: PinnedSource
    package let frameTimes: [Double]

    // The number of the page pinned, nil for every medium that is no page of a PDF.
    var page: Int? {
        guard case let .page(_, page) = source else { return nil }

        return page
    }

    // MARK: - Initializer
    package init(
        source: PinnedSource,
        frameTimes: [Double] = []
    ) {
        self.source = source
        self.frameTimes = frameTimes
    }

    // MARK: - Public
    // The index of the frame shown at the media time: the last that starts at or before it, or the first before the
    // media starts. A still has the one frame 0.
    func frameIndex(at time: Double) -> Int {
        frameTimes.lastIndex { $0.roundedTime <= time.roundedTime } ?? 0
    }

    // MARK: - Private
}
