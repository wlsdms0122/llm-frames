//
//  ResolvedMediaTiming.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a timed media clip plays: from `in` at sequence time `origin` at `speed`, up to `out`, in media time, and whether
// it repeats from `in` past `out`. `origin` is the start of the clip's window before tracking narrowed it, so it can lie
// before the clip's `start`.
struct ResolvedMediaTiming: Equatable, Sendable {
    // MARK: - Property
    let `in`: Double
    let origin: Double
    let out: Double
    let speed: Double
    let loop: Bool

    // MARK: - Initializer
    init(
        in: Double,
        origin: Double,
        out: Double,
        speed: Double,
        loop: Bool
    ) {
        self.in = `in`
        self.origin = origin
        self.out = out
        self.speed = speed
        self.loop = loop
    }

    // MARK: - Public
    // MARK: - Private
}
