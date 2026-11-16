//
//  ResolvedMediaTiming+MediaTime.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The media time a timed media clip shows at a sequence time: `in` at `origin`, at `speed`, up to `out` by the time
// map's rule.
extension ResolvedMediaTiming {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func mediaTime(at time: Double) -> Double {
        TimeMap(origin: origin, in: `in`, speed: speed).clipTime(atSequenceTime: time, out: out, loop: loop)
    }

    // MARK: - Private
}
