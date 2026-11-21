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
// anything is mixed. A document's mix is checked as `render` checks it, so a file changed since it was resolved stops.
package struct LoudnessReporter: Sendable {
    // MARK: - Property
    private let mixer: any Mixer
    private let mediaFacts: any MediaFactProvider
    private let pinned: PinnedReferenceChecker

    // MARK: - Initializer
    package init(
        decoder: any MediaDecoder,
        mixer: any Mixer,
        mediaFacts: any MediaFactProvider
    ) {
        self.init(decoder: decoder, mixer: mixer, mediaFacts: mediaFacts, hasher: FileHasher())
    }

    init(
        decoder: any MediaDecoder,
        mixer: any Mixer,
        mediaFacts: any MediaFactProvider,
        hasher: any FileHashProvider
    ) {
        self.mixer = mixer
        self.mediaFacts = mediaFacts
        self.pinned = PinnedReferenceChecker(decoder: decoder, hasher: hasher)
    }

    // MARK: - Public
    package func loudness(
        of sequence: ResolvedSequence,
        from: Double?,
        to: Double?
    ) throws -> Loudness {
        let mix = try SequenceMix(of: sequence, pinned: pinned, mixer: mixer)

        return try loudness(of: mix, end: Double(mix.plan.length) / Double(MixPlan.sampleRate), from: from, to: to)
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
        guard let medium = try mediaFacts.probedMedium(of: path) else { throw AnalysisError.missingMedia(file: path) }
        guard case let .media(probed) = medium, probed.sound != nil else { throw AnalysisError.noSound(file: path) }

        let mix = try SequenceMix(ofMedium: path, duration: probed.duration, mixer: mixer)

        return try loudness(of: mix, end: probed.duration, from: from, to: to)
    }

    // MARK: - Private
    // The measures of `mix` over [from, to), its sound ending at `end` seconds. It is mixed only after the range checks
    // out.
    private func loudness(
        of mix: SequenceMix,
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

        let sound = try mix.mixed()
        let first = min(firstSample(atOrAfter: start), sound.frameCount)
        let last = min(firstSample(atOrAfter: stop), sound.frameCount)

        return LoudnessMeter().measure(sound, over: first..<max(first, last)).rounded()
    }

    // The first sample n whose time n / 48000 is at or after `time`, counted in whole microseconds so the count is exact.
    private func firstSample(atOrAfter time: Double) -> Int {
        let ticks = time.timeTicks
        let samples = ticks * MixPlan.sampleRate

        return (samples + 999_999) / 1_000_000
    }
}
