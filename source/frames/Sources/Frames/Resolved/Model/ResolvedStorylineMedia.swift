//
//  ResolvedStorylineMedia.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The media a storyline entry shows. `colorSpace` is the space that overrides its file's tags, nil where they apply,
// and `isToneMapped` its `toneMap`, nil for a page, which takes none, and for a nested sequence, whose pictures are
// working values already. `timeRemap` is keyframes in sequence time whose values are media seconds, nil for none, when
// clip time is media time.
struct ResolvedStorylineMedia: Equatable, Sendable {
    // MARK: - Property
    let media: ResolvedMediaContent
    let colorSpace: ColorSpace?
    let isToneMapped: Bool?
    let timeRemap: [Keyframe<Double>]?

    // MARK: - Initializer
    init(
        media: ResolvedMediaContent,
        colorSpace: ColorSpace? = nil,
        isToneMapped: Bool? = nil,
        timeRemap: [Keyframe<Double>]? = nil
    ) {
        self.media = media
        self.colorSpace = colorSpace
        self.isToneMapped = isToneMapped
        self.timeRemap = timeRemap
    }

    // MARK: - Public
    // MARK: - Private
}
