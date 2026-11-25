//
//  ResolvedSequence+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve decided for a sequence, each storyline clip and other clip from its time plan and what was found for it.
// An audio clip is drawn by nothing, so it is a source of sound only.
extension ResolvedSequence {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: SequencePlan,
        hashes: any FileHashProvider
    ) throws {
        let time = plan.time

        self.init(
            format: ResolvedFormat(plan: plan.format),
            storyline: try time.storyline.indices.map { index in
                try ResolvedStorylineClip(
                    plan: time.storyline[index],
                    geometry: plan.storyline[index],
                    format: plan.format,
                    hashes: hashes
                )
            },
            clips: try time.clips.indices
                .compactMap { try ResolvedClip(plan: time.clips[$0], geometry: plan.clips[$0], hashes: hashes) },
            audio: try plan.sound.map { try ResolvedSound(plan: $0, hashes: hashes) },
            audioFilter: try plan.audioFilter.pinningFiles(hashes: hashes)
        )
    }

    // MARK: - Public
    // MARK: - Private
}
