//
//  ResolvedSound+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A source of sound as resolve planned it. It plays its media, or the sounds of its nested sequence on their own clock,
// and its volume holds from the start of its range when it has no keyframes.
extension ResolvedSound {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: SoundPlan,
        hashes: any FileHashProvider
    ) throws {
        let media: PinnedMedia? = if case let .file(file) = plan.media.source {
            try PinnedMedia(file: file, hashes: hashes)
        } else {
            nil
        }

        self.init(
            place: plan.place.description,
            media: media,
            nested: try plan.nested.map { try ResolvedSound(plan: $0, hashes: hashes) },
            played: plan.played,
            start: plan.range.start,
            end: plan.range.end,
            audible: plan.audible,
            volume: plan.volume.keyframes(at: plan.range.start) { $0 },
            fadeIn: plan.fadeIn,
            fadeOut: plan.fadeOut,
            incoming: plan.incoming,
            outgoing: plan.outgoing
        )
    }

    // MARK: - Public
    // MARK: - Private
}
