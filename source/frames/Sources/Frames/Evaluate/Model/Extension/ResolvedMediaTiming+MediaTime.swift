//
//  ResolvedMediaTiming+MediaTime.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The media time a timed media clip shows at a sequence time: `in` at `origin`, at `speed`. Past `out` a looping clip
// repeats from `in`, and any other holds the last frame before `out`.
extension ResolvedMediaTiming {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func mediaTime(at time: Double) -> Double {
        let mediaTime = TimeMap(origin: origin, in: `in`, speed: speed).clipTime(atSequenceTime: time)
        guard mediaTime.roundedTime >= out.roundedTime else { return mediaTime }

        return loop ? `in` + (mediaTime - `in`).truncatingRemainder(dividingBy: out - `in`) : out - .timeResolution
    }

    // MARK: - Private
}
