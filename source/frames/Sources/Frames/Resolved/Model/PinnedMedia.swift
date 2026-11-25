//
//  PinnedMedia.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Media as the resolved document pins it: its files, and the media time of each frame of a video or image sequence in
// frame order.
package struct PinnedMedia: Equatable, Sendable {
    // MARK: - Property
    package let source: PinnedSource

    // The number of the page pinned, nil for every medium that is no page of a PDF.
    package var page: Int? {
        guard case let .page(_, page) = source else { return nil }
        return page
    }

    // The media time of each frame in frame order, nil for an image, a page and a sound file, which have no frames.
    package var frameTimes: [Double]? {
        switch source {
        case let .file(_, frameTimes):
            frameTimes

        case let .imageSequence(_, frameTimes):
            frameTimes

        case .page:
            nil
        }
    }

    // MARK: - Initializer
    package init(source: PinnedSource) {
        self.source = source
    }

    // MARK: - Public
    // The media time of the frame shown at the media time, nil for a still.
    func frameTime(at time: Double) -> Double? {
        frameTimes.map { frameTimes in frameTimes[frameIndex(at: time)] }
    }

    // The index of the frame shown at the media time: the last that starts at or before it, or the first before the
    // media starts. A still has the one frame 0.
    func frameIndex(at time: Double) -> Int {
        frameTimes?.lastIndex { $0.roundedTime <= time.roundedTime } ?? 0
    }

    // MARK: - Private
}
