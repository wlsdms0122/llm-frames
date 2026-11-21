//
//  FrameTiming.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import CoreMedia
import Foundation
import Frames

// When each frame of a video at `fps` is presented: frame k at k / fps at the rate frames presents (`FrameRate`), on a
// timescale that holds those times exactly: n × 1000 for a whole rate n or an NTSC rate n × 1000 / 1001. Any other rate
// rounds each time on its own to a microsecond, so times never drift.
struct FrameTiming: Equatable, Sendable {
    // MARK: - Property
    private static let fineTimescale: CMTimeScale = 1_000_000

    let timescale: CMTimeScale
    let rate: Double

    // MARK: - Initializer
    init(fps: Double) {
        let presented = FrameRate(fps: fps)

        switch presented {
        case let .whole(rate):
            timescale = CMTimeScale(rate * 1000)

        case let .ntsc(base):
            timescale = CMTimeScale(base * 1000)

        case .other:
            timescale = Self.fineTimescale
        }
        rate = presented.value
    }

    // MARK: - Public
    // The time frame `index` is presented at, which is also where the frames before it end.
    func time(ofFrame index: Int) -> CMTime {
        CMTime(value: CMTimeValue((Double(index) * Double(timescale) / rate).rounded()), timescale: timescale)
    }

    // MARK: - Private
}
