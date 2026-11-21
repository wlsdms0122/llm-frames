//
//  FrameRate.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A frame rate as frames presents it. A rate within a hundred-thousandth of itself from a whole rate n is n, and one as
// near the NTSC rate n × 1000 / 1001 is that rate, so the 29.999998 a container's timescale makes of 30 is 30 and a
// written 29.97 is 30000 / 1001. Any other rate is presented as it is written.
package enum FrameRate: Equatable, Sendable {
    case whole(Int)
    case ntsc(Int)
    case other(Double)

    // MARK: - Property
    // Frames per second.
    package var value: Double {
        switch self {
        case let .whole(rate):
            Double(rate)

        case let .ntsc(base):
            Double(base) * 1000 / 1001

        case let .other(rate):
            rate
        }
    }

    // MARK: - Initializer
    package init(fps: Double) {
        let whole = fps.rounded()
        let ntsc = (fps * 1.001).rounded()

        if abs(fps - whole) <= fps * 1e-5 {
            self = .whole(Int(whole))
        } else if abs(fps - ntsc * 1000 / 1001) <= fps * 1e-5 {
            self = .ntsc(Int(ntsc))
        } else {
            self = .other(fps)
        }
    }

    // MARK: - Public
    // The samples at `sampleRate` a second that `frames` frames last, rounded to the nearest whole number, halves up.
    // A whole or NTSC rate is counted in whole numbers, so the count is exact.
    package func samples(
        ofFrames frames: Int,
        sampleRate: Int
    ) -> Int {
        switch self {
        case let .whole(rate):
            (2 * frames * sampleRate + rate) / (2 * rate)

        case let .ntsc(base):
            (2 * frames * sampleRate * 1001 + base * 1000) / (2 * base * 1000)

        case let .other(rate):
            Int((Double(frames) * Double(sampleRate) / rate).rounded())
        }
    }

    // MARK: - Private
}
