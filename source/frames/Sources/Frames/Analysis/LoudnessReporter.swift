//
//  LoudnessReporter.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

import Foundation

// Measures one mix with the loudness meter, as `loudness` prints it. A document's mix is the plan's whole mix, its
// `length` samples from sequence time 0, and a medium's is the mix of the sequence that plays one clip of it from
// media time 0 at volume 1, centred and at speed 1 with no audio filter, as long as its sound. `from` and `to` are
// media time for a medium and sequence time for a document, from 0 and to the end of the sound when nil. The range is
// the samples n whose time n / 48000 lies in [from, to), and a range outside the sound or out of order stops before
// anything is mixed.
package struct LoudnessReporter: Sendable {
    // MARK: - Property
    private let mediaFacts: any MediaFactProvider
    private let mixer: any Mixer

    // MARK: - Initializer
    package init(
        mediaFacts: any MediaFactProvider,
        mixer: any Mixer
    ) {
        self.mediaFacts = mediaFacts
        self.mixer = mixer
    }

    // MARK: - Public
    package func loudness(
        of sequence: ResolvedSequence,
        from: Double?,
        to: Double?
    ) throws -> Loudness {
        let plan = MixPlanner().mix(of: sequence)

        return try loudness(of: plan, end: Double(plan.length) / Double(MixPlan.sampleRate), from: from, to: to)
    }

    package func loudness(
        ofMedium path: String,
        from: Double?,
        to: Double?
    ) throws -> Loudness {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
            throw AnalysisError.noSound(file: path)
        }
        guard let probed = try mediaFacts.probedMedia(of: path) else { throw AnalysisError.missingMedia(file: path) }
        guard probed.sound != nil else { throw AnalysisError.noSound(file: path) }

        let end = probed.duration
        // The plan is mixed here and never written, so its file is not pinned and nothing reads its digest.
        let segment = MixSegment(
            media: PinnedMedia(source: .file(PinnedFile(path: path, sha256: ""))),
            mediaStart: 0,
            speed: 1,
            start: 0,
            end: end,
            envelope: [EnvelopePoint(time: 0, value: 1), EnvelopePoint(time: end, value: 1)],
            pan: [EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: end, value: 0)]
        )
        let length = Int((end * Double(MixPlan.sampleRate)).rounded())

        return try loudness(of: MixPlan(length: length, segments: [segment]), end: end, from: from, to: to)
    }

    // MARK: - Private
    // The measures of `plan`'s mix over [from, to), its sound ending at `end` seconds.
    private func loudness(
        of plan: MixPlan,
        end: Double,
        from: Double?,
        to: Double?
    ) throws -> Loudness {
        let start = from ?? 0
        let stop = to ?? end
        guard start >= 0 else { throw AnalysisError.beforeSoundStart(option: "--from", time: start) }
        guard start < end else { throw AnalysisError.atOrAfterSoundEnd(option: "--from", time: start, end: end) }
        guard stop <= end else { throw AnalysisError.afterSoundEnd(option: "--to", time: stop, end: end) }
        guard start < stop else { throw AnalysisError.emptyRange(from: start, to: stop) }

        try mixer.check(plan)
        let mix = try mixer.mix(plan)
        let first = min(firstSample(atOrAfter: start), mix.frameCount)
        let last = min(firstSample(atOrAfter: stop), mix.frameCount)

        return LoudnessMeter().measure(mix, over: first..<max(first, last)).rounded()
    }

    // The first sample n whose time n / 48000 is at or after `time`, counted in whole microseconds so the count is exact.
    private func firstSample(atOrAfter time: Double) -> Int {
        let ticks = time.timeTicks
        let samples = ticks * MixPlan.sampleRate

        return (samples + 999_999) / 1_000_000
    }
}
