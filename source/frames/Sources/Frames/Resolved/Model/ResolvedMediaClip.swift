//
//  ResolvedMediaClip.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A media clip's picture: what it shows, how its pictures are read, how a timed one plays (nil for a still), its filter,
// and how it fills its box. `colorSpace` is the space that overrides the file's tags, nil where they apply, and
// `isToneMapped` the clip's `toneMap`, nil for a nested sequence, whose pictures are working values already.
struct ResolvedMediaClip: Equatable, Sendable {
    // MARK: - Property
    let media: ResolvedMediaContent
    let colorSpace: ColorSpace?
    let isToneMapped: Bool?
    let timing: MediaTiming?
    let filter: TimedValue
    let appearance: ResolvedMediaAppearance

    // The media time a timed clip shows, nil for a still.
    var clock: MediaClock? {
        timing.map { timing in MediaClock(timing: timing, frames: media.frames) }
    }

    // MARK: - Initializer
    init(
        media: ResolvedMediaContent,
        colorSpace: ColorSpace? = nil,
        isToneMapped: Bool? = nil,
        timing: MediaTiming?,
        filter: TimedValue,
        appearance: ResolvedMediaAppearance
    ) {
        self.media = media
        self.colorSpace = colorSpace
        self.isToneMapped = isToneMapped
        self.timing = timing
        self.filter = filter
        self.appearance = appearance
    }

    // MARK: - Public
    // MARK: - Private
}
