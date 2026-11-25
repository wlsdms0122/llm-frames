//
//  ResolvedSound+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A source of sound as resolve planned it. It plays its media, or the sounds of its nested sequence on their own clock,
// and its volume and pan hold from the start of its range when they have no keyframes.
extension ResolvedSound {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: SoundPlan,
        hashes: any FileHashProvider
    ) throws {
        let source: ResolvedSoundSource = switch plan.media.source {
        case let .file(file):
            .pinned(try PinnedMedia(file: file, hashes: hashes))

        case .sequence:
            .nested(
                try plan.nested.map { try ResolvedSound(plan: $0, hashes: hashes) },
                audioFilter: try plan.nestedAudioFilter.pinningFiles(hashes: hashes)
            )
        }

        self.init(
            place: plan.place.description,
            source: source,
            played: plan.played,
            start: plan.range.start,
            end: plan.range.end,
            audible: plan.audible,
            volume: plan.volume.keyframes(at: plan.range.start) { $0 },
            pan: plan.pan.keyframes(at: plan.range.start) { $0 },
            fadeIn: plan.fadeIn,
            fadeOut: plan.fadeOut,
            incoming: plan.incoming,
            outgoing: plan.outgoing,
            audioFilter: try plan.audioFilter.pinningFiles(hashes: hashes)
        )
    }

    // MARK: - Public
    // MARK: - Private
}
