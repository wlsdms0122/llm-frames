//
//  ClipMedia.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The media of a clip and how it plays, each value nil when left to its default. `in` and `out` are clip time,
// `timeRemap`, `volume` and `pan` keyframes are on the clip's clock, and `fadeIn` and `fadeOut` are sequence seconds.
// `colorSpace` is the space its pictures are read in where the file's tags do not apply, and `isToneMapped` its
// `toneMap`. `picture` false takes only the media's sound, `audioFilter` is the clip's audio filter as written, and
// `split` moves the edges of its sound.
struct ClipMedia: Equatable, Sendable {
    // MARK: - Property
    let source: MediaSource
    let colorSpace: ColorSpace?
    let isToneMapped: Bool?
    let `in`: Double?
    let out: Double?
    let speed: Double?
    let loop: Bool?
    let timeRemap: PropertyValue<Double>?
    let volume: PropertyValue<Double>?
    let pan: PropertyValue<Double>?
    let fadeIn: Double?
    let fadeOut: Double?
    let picture: Bool?
    let audioFilter: LookProperty?
    let split: SplitEdit?

    // MARK: - Initializer
    init(
        source: MediaSource,
        colorSpace: ColorSpace? = nil,
        isToneMapped: Bool? = nil,
        in: Double? = nil,
        out: Double? = nil,
        speed: Double? = nil,
        loop: Bool? = nil,
        timeRemap: PropertyValue<Double>? = nil,
        volume: PropertyValue<Double>? = nil,
        pan: PropertyValue<Double>? = nil,
        fadeIn: Double? = nil,
        fadeOut: Double? = nil,
        picture: Bool? = nil,
        audioFilter: LookProperty? = nil,
        split: SplitEdit? = nil
    ) {
        self.source = source
        self.colorSpace = colorSpace
        self.isToneMapped = isToneMapped
        self.in = `in`
        self.out = out
        self.speed = speed
        self.loop = loop
        self.timeRemap = timeRemap
        self.volume = volume
        self.pan = pan
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
        self.picture = picture
        self.audioFilter = audioFilter
        self.split = split
    }

    // MARK: - Public
    // MARK: - Private
}
