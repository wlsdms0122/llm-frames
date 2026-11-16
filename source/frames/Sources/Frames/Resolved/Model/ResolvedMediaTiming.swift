//
//  ResolvedMediaTiming.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a timed media clip plays: from `in` at the start of its window at `speed`, up to `out`, in media time, and
// whether it repeats from `in` past `out`.
struct ResolvedMediaTiming: Equatable, Sendable {
    // MARK: - Property
    let `in`: Double
    let out: Double
    let speed: Double
    let loop: Bool

    // MARK: - Initializer
    init(
        in: Double,
        out: Double,
        speed: Double,
        loop: Bool
    ) {
        self.in = `in`
        self.out = out
        self.speed = speed
        self.loop = loop
    }

    // MARK: - Public
    // MARK: - Private
}
