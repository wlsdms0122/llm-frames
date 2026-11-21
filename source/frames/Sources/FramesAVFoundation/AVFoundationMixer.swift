//
//  AVFoundationMixer.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation
import Frames

// The `avfoundation` mixer: reads each segment's media time through the decoder, maps its channels onto stereo,
// resamples it to the plan's sample rate, stretches it in time with the pitch kept when its speed is not 1, runs its
// audio filter, multiplies it by its envelope, pans it by its pan envelope with the pan law of its channel count, and
// adds it into the bus that holds it from its start sample. A bus sums its segments and buses over its span, runs its
// chain over the sum, at rest at the span's first sample, and multiplies the result by its level envelope before it is
// added to the bus that holds it. The plan is the outermost bus: its chain runs over the whole sum of its `length`
// samples, and that is the mix, interleaved in place, so the mix is held once. The sum is not clipped.
package final class AVFoundationMixer: Sendable {
    // MARK: - Property
    private static let sampleRate = Double(MixPlan.sampleRate)

    private let decoder: any MediaDecoder

    // MARK: - Initializer
    package init(decoder: any MediaDecoder) {
        self.decoder = decoder
    }

    // MARK: - Public
    // MARK: - Private
    // `place` is the place in the plan of the bus that holds `segments` and `buses`, as `buses[0].`, empty for the plan.
    private func check(
        segments: [MixSegment],
        buses: [MixBus],
        place: String
    ) throws {
        for (index, segment) in segments.enumerated() {
            let place = "\(place)segments[\(index)]"
            let (path, sound) = try sound(of: segment, place: place, from: segment.mediaStart, to: segment.mediaStart)
            guard StereoDownmixer(layout: sound.layout) != nil else {
                throw MixerError.unmixableChannels(segment: place, file: path)
            }
            guard segment.speed == 1 || TimeStretcher.speeds.contains(segment.speed) else {
                throw MixerError.unstretchable(segment: place, file: path, speed: segment.speed)
            }
        }
        for (index, bus) in buses.enumerated() {
            try check(segments: bus.segments, buses: bus.buses, place: "\(place)buses[\(index)].")
        }
    }

    // The sum of `segments` and `buses` over the sequence samples `span`, planar: the left channel's `span.count`
    // samples, then the right channel's, sample 0 of each at `span.lowerBound`. `place` is as in `check`.
    private func sum(
        segments: [MixSegment],
        buses: [MixBus],
        over span: Range<Int>,
        place: String
    ) throws -> [Float] {
        var sum = [Float](repeating: 0, count: span.count * 2)
        for (index, segment) in segments.enumerated() {
            try add(segment, place: "\(place)segments[\(index)]", over: span, into: &sum)
        }
        for (index, bus) in buses.enumerated() {
            try add(bus, place: "\(place)buses[\(index)].", over: span, into: &sum)
        }

        return sum
    }

    private func add(
        _ segment: MixSegment,
        place: String,
        over span: Range<Int>,
        into sum: inout [Float]
    ) throws {
        let first = sample(at: segment.start)
        let last = min(sample(at: segment.end), span.upperBound)
        guard first < last else { return }

        let (path, sound) = try sound(
            of: segment,
            place: place,
            from: segment.mediaStart,
            to: segment.mediaStart + (segment.end - segment.start) * segment.speed
        )
        guard let downmixer = StereoDownmixer(layout: sound.layout) else {
            throw MixerError.unmixableChannels(segment: place, file: path)
        }
        var buffer = try downmixer.stereo(from: sound, path: path)
        buffer = try Resampler().resampled(buffer, to: Self.sampleRate, path: path)
        if segment.speed != 1 {
            guard TimeStretcher.speeds.contains(segment.speed) else {
                throw MixerError.unstretchable(segment: place, file: path, speed: segment.speed)
            }
            buffer = try TimeStretcher().stretched(buffer, speed: segment.speed, path: path)
        }

        let law = PanLaw(layout: sound.layout)
        let gains = segment.gains(atSamples: first..<last, sampleRate: Self.sampleRate)
        let pans = segment.pans(atSamples: first..<last, sampleRate: Self.sampleRate)
        let heard = min(last - first, Int(buffer.frameLength))
        let from = max(span.lowerBound - first, 0)
        guard from < heard, let channels = buffer.floatChannelData else { return }
        SegmentFilter(filter: segment.filter, sampleRate: Self.sampleRate)
            .process(buffer, frames: heard, first: first)
        let offset = first - span.lowerBound
        for frame in from..<heard {
            let gain = gains[frame]
            let panned = law.gains(at: pans[frame])
            sum[offset + frame] += channels[0][frame] * gain * panned.left
            sum[span.count + offset + frame] += channels[1][frame] * gain * panned.right
        }
    }

    private func add(
        _ bus: MixBus,
        place: String,
        over span: Range<Int>,
        into sum: inout [Float]
    ) throws {
        let first = max(sample(at: bus.start), span.lowerBound)
        let last = min(sample(at: bus.end), span.upperBound)
        guard first < last else { return }

        let count = last - first
        var bused = try self.sum(segments: bus.segments, buses: bus.buses, over: first..<last, place: place)
        filter(&bused, frames: count, by: bus.filter, first: first)
        let gains = bus.gains(atSamples: first..<last, sampleRate: Self.sampleRate)
        let offset = first - span.lowerBound
        for frame in 0..<count {
            sum[offset + frame] += bused[frame] * gains[frame]
            sum[span.count + offset + frame] += bused[count + frame] * gains[frame]
        }
    }

    // Runs `filter` in place over a planar sum of `frames` samples per channel, at rest at sequence sample `first`.
    private func filter(
        _ sum: inout [Float],
        frames: Int,
        by filter: [MixFilterEntry],
        first: Int
    ) {
        guard !filter.isEmpty, frames > 0 else { return }

        sum.withUnsafeMutableBufferPointer { samples in
            guard let left = samples.baseAddress else { return }

            SegmentFilter(filter: filter, sampleRate: Self.sampleRate)
                .process([left, left + frames], frames: frames, first: first)
        }
    }

    // Interleaves a planar stereo sum of `frames` samples per channel in place: left sample k moves to 2k and right
    // sample k to 2k + 1. That moves place p to 2p mod (2 frames - 1), every place but the last, which stays, and the
    // move is made one cycle of places at a time, a bit a place marking the places already filled.
    private func interleave(
        _ samples: inout [Float],
        frames: Int
    ) {
        let modulus = 2 * frames - 1
        guard modulus > 2 else { return }

        var filled = [UInt64](repeating: 0, count: modulus / 64 + 1)
        samples.withUnsafeMutableBufferPointer { samples in
            for start in 1..<modulus where filled[start / 64] & (1 << (start % 64)) == 0 {
                var place = start
                var carried = samples[start]
                repeat {
                    place = 2 * place % modulus
                    swap(&carried, &samples[place])
                    filled[place / 64] |= 1 << (place % 64)
                } while place != start
            }
        }
    }

    // The first sample of a span edge at `time`, by the span rule: round(sample rate × time), halves up.
    private func sample(at time: Double) -> Int {
        Int((time * Self.sampleRate).rounded())
    }

    // The segment's media time [from, to) as the decoder reads it, its failures named by the segment's place.
    private func sound(
        of segment: MixSegment,
        place: String,
        from start: Double,
        to end: Double
    ) throws -> (path: String, sound: SoundBuffer) {
        let file: MediaFile
        switch segment.media {
        case let .pinned(media):
            file = MediaFile(media: media)
            guard case .file = media.source else { throw MixerError.noSound(segment: place, file: file.path) }

        case let .unpinned(path):
            file = MediaFile(path: path)
        }

        do {
            return (file.path, try decoder.sound(of: file, from: start, to: end))
        } catch DecoderError.noSound {
            throw MixerError.noSound(segment: place, file: file.path)
        } catch {
            throw MixerError.unreadable(segment: place, reason: "\(error)")
        }
    }
}

extension AVFoundationMixer: Mixer {
    // MARK: - Lifecycle
    package func check(_ plan: MixPlan) throws {
        try check(segments: plan.segments, buses: plan.buses, place: "")
    }

    package func mix(_ plan: MixPlan) throws -> SoundBuffer {
        let length = plan.length
        var samples = try sum(segments: plan.segments, buses: plan.buses, over: 0..<length, place: "")
        filter(&samples, frames: length, by: plan.filter, first: 0)
        interleave(&samples, frames: length)

        return SoundBuffer(sampleRate: Self.sampleRate, channels: 2, samples: samples)
    }
}
