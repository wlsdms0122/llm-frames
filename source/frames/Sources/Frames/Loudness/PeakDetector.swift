//
//  PeakDetector.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

import Accelerate

// The detector the limiter limits by and the meter reads its true peak with: P[n] is the largest of |x_c[n]| and the
// eight values |u_c,p[n + 5]| and |u_c,p[n + 6]| of the interpolating filter over every channel c, the sample and the
// oversampled values of the two intervals beside it. The sound is read as 0 before its sample 0 and from its `count`.
package struct PeakDetector: Sendable {
    // MARK: - Property
    // The samples of P computed at once, which bounds the scratch memory a sound of any length takes.
    private static let chunk = 65_536

    private let filter = InterpolatingFilter()

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    // Writes P[n] for n from `start` to start + peaks.count - 1 into `peaks`. Each channel holds `count` samples,
    // `stride` apart.
    package func peaks(
        of channels: [UnsafePointer<Float>],
        stride: Int,
        count: Int,
        from start: Int,
        into peaks: UnsafeMutableBufferPointer<Float>
    ) {
        guard let base = peaks.baseAddress else { return }

        let window = UnsafeMutablePointer<Float>.allocate(capacity: Self.chunk + InterpolatingFilter.tapCount)
        let values = UnsafeMutablePointer<Float>.allocate(capacity: Self.chunk + 1)
        let intervals = UnsafeMutablePointer<Float>.allocate(capacity: Self.chunk + 1)
        defer {
            window.deallocate()
            values.deallocate()
            intervals.deallocate()
        }

        var offset = 0
        while offset < peaks.count {
            let length = min(Self.chunk, peaks.count - offset)
            let first = start + offset
            // The intervals beside P[first] to P[first + length - 1] are u[first + 5] to u[first + length + 5].
            vDSP_vclr(intervals, 1, vDSP_Length(length + 1))
            for channel in channels {
                fill(window, from: channel, stride: stride, count: count, at: first + 5 - 11, length: length + 12)
                for phase in 0..<InterpolatingFilter.phases.count {
                    filter.values(ofPhase: phase, window: window, into: values, count: length + 1)
                    vDSP_vmaxmg(values, 1, intervals, 1, intervals, 1, vDSP_Length(length + 1))
                }
            }
            for index in 0..<length {
                let sample = first + index
                var peak = max(intervals[index], intervals[index + 1])
                if sample >= 0 && sample < count {
                    for channel in channels {
                        peak = max(peak, abs(channel[sample * stride]))
                    }
                }
                base[offset + index] = peak
            }
            offset += length
        }
    }

    // The largest P[n] for n in `range`.
    package func peak(
        of channels: [UnsafePointer<Float>],
        stride: Int,
        count: Int,
        over range: Range<Int>
    ) -> Float {
        var peaks = [Float](repeating: 0, count: min(Self.chunk, range.count))
        var largest: Float = 0
        var start = range.lowerBound
        while start < range.upperBound {
            let length = min(Self.chunk, range.upperBound - start)
            var chunkPeak: Float = 0
            peaks.withUnsafeMutableBufferPointer { peaks in
                let part = UnsafeMutableBufferPointer(rebasing: peaks[0..<length])
                self.peaks(of: channels, stride: stride, count: count, from: start, into: part)
                vDSP_maxv(part.baseAddress!, 1, &chunkPeak, vDSP_Length(length))
            }
            largest = max(largest, chunkPeak)
            start += length
        }
        return largest
    }

    // MARK: - Private
    // Copies samples `first` to first + length - 1 of `channel` into `window`, 0 outside the sound.
    private func fill(
        _ window: UnsafeMutablePointer<Float>,
        from channel: UnsafePointer<Float>,
        stride: Int,
        count: Int,
        at first: Int,
        length: Int
    ) {
        for index in 0..<length {
            let sample = first + index
            window[index] = sample >= 0 && sample < count ? channel[sample * stride] : 0
        }
    }
}
