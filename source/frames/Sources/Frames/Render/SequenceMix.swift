//
//  SequenceMix.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The mix of a resolved sequence through the mixer role, as `render` and `loudness` make it. It is made only after
// every file the sequence pins checks out, its plan is made and the mixer accepts the plan, so a changed file or a plan
// the mixer cannot play stops before anything is mixed.
struct SequenceMix: Sendable {
    // MARK: - Property
    let plan: MixPlan

    private let mixer: any Mixer

    // MARK: - Initializer
    init(
        of sequence: ResolvedSequence,
        pinned: PinnedReferenceChecker,
        mixer: any Mixer
    ) throws {
        try pinned.check(sequence.pinnedReferences)
        let plan = MixPlanner().mix(of: sequence)
        try mixer.check(plan)

        self.plan = plan
        self.mixer = mixer
    }

    // MARK: - Public
    func mixed() throws -> SoundBuffer {
        try mixer.mix(plan)
    }

    // MARK: - Private
}
