//
//  SequenceMix.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The mix of a sequence through the mixer role, as `render` and `loudness` make it. It is made only after every file a
// resolved sequence pins checks out, its plan is made and the mixer accepts the plan, so a changed file or a plan the
// mixer cannot play stops before anything is mixed. The sequence that plays one clip of a medium pins nothing.
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
        try self.init(plan: MixPlanner().mix(of: sequence), mixer: mixer)
    }

    // The mix of the sequence that plays one clip of the medium at `path`, as long as its sound, `duration` seconds.
    init(
        ofMedium path: String,
        duration: Double,
        mixer: any Mixer
    ) throws {
        try self.init(plan: MixPlanner().mix(ofMedium: path, duration: duration), mixer: mixer)
    }

    private init(
        plan: MixPlan,
        mixer: any Mixer
    ) throws {
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
