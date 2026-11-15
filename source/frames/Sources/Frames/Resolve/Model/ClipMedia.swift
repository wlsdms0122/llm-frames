//
//  ClipMedia.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The media of a clip and its edit points as written, in media time. Each is nil when left to its default.
struct ClipMedia: Equatable, Sendable {
    // MARK: - Property
    let source: MediaSource
    let `in`: Double?
    let out: Double?
    let speed: Double?
    let loop: Bool

    // MARK: - Initializer
    init(
        source: MediaSource,
        in: Double? = nil,
        out: Double? = nil,
        speed: Double? = nil,
        loop: Bool = false
    ) {
        self.source = source
        self.in = `in`
        self.out = out
        self.speed = speed
        self.loop = loop
    }

    // MARK: - Public
    // MARK: - Private
}
