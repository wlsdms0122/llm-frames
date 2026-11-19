//
//  ClipMedia.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The media of a clip and how it plays, each value nil when left to its default. `in` and `out` are clip time,
// `timeRemap`, `volume` and `pan` keyframes are on the clip's clock, and `fadeIn` and `fadeOut` are sequence seconds.
// `picture` false takes only the media's sound.
struct ClipMedia: Equatable, Sendable {
    // MARK: - Property
    let source: MediaSource
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

    // MARK: - Initializer
    init(
        source: MediaSource,
        in: Double? = nil,
        out: Double? = nil,
        speed: Double? = nil,
        loop: Bool? = nil,
        timeRemap: PropertyValue<Double>? = nil,
        volume: PropertyValue<Double>? = nil,
        pan: PropertyValue<Double>? = nil,
        fadeIn: Double? = nil,
        fadeOut: Double? = nil,
        picture: Bool? = nil
    ) {
        self.source = source
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
    }

    // MARK: - Public
    // MARK: - Private
}
