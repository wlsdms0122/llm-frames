//
//  FrameTiming.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import CoreMedia
import Foundation

// When each frame of a video at `fps` is presented: frame k at k / fps, on a timescale that holds those times
// exactly. A rate within a hundred-thousandth of a whole number n is n, with timescale n × 1000 and frames 1000 long,
// so the 29.999998 a container's timescale makes of 30 is 30. A rate within a hundred-thousandth of n × 1000 / 1001 is
// that NTSC rate, as 29.97 is 30000 / 1001, with timescale n × 1000 and frames 1001 long. Any other rate rounds each
// time on its own to a microsecond, so times never drift.
struct FrameTiming: Equatable, Sendable {
    // MARK: - Property
    private static let fineTimescale: CMTimeScale = 1_000_000

    let timescale: CMTimeScale
    let rate: Double

    // MARK: - Initializer
    init(fps: Double) {
        let whole = fps.rounded()
        let ntsc = (fps * 1.001).rounded()

        if abs(fps - whole) <= fps * 1e-5 {
            timescale = CMTimeScale(whole * 1000)
            rate = whole
        } else if abs(fps - ntsc * 1000 / 1001) <= fps * 1e-5 {
            timescale = CMTimeScale(ntsc * 1000)
            rate = ntsc * 1000 / 1001
        } else {
            timescale = Self.fineTimescale
            rate = fps
        }
    }

    // MARK: - Public
    // The time frame `index` is presented at, which is also where the frames before it end.
    func time(ofFrame index: Int) -> CMTime {
        CMTime(value: CMTimeValue((Double(index) * Double(timescale) / rate).rounded()), timescale: timescale)
    }

    // MARK: - Private
}
