//
//  StorylineTrack.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The track a clip parented to a storyline clip follows (FRAMES-12), with that storyline clip's plan, whose clock gives
// the media time of a sequence time. A tracked clip's keyframes are where they lie on the frame at their own `at`, and
// each is brought back through the motion at the media time there to where it lies at the instant, as its evaluation
// brings them back.
struct StorylineTrack: Equatable, Sendable {
    // MARK: - Property
    let track: Track
    let storyline: StorylinePlan

    // MARK: - Initializer
    init(
        track: Track,
        storyline: StorylinePlan
    ) {
        self.track = track
        self.storyline = storyline
    }

    // The track of a clip of the plan, nil unless it is tracked and parented to a storyline clip.
    init?(
        clip index: Int,
        in plan: TrackPlan
    ) {
        guard let track = plan.clips[index], case let .storyline(storyline, _) = plan.time.clips[index].parent else {
            return nil
        }

        self.init(track: track, storyline: plan.time.storyline[storyline])
    }

    // MARK: - Public
    func motion(at time: Double) -> TrackMotion {
        track.motion(atMediaTime: storyline.mediaTime(atSequenceTime: time))
    }

    func area(_ keyframes: [Keyframe<Rectangle>]) -> [Keyframe<Rectangle>] {
        keyframes.map { keyframe in
            Keyframe(at: keyframe.at, value: motion(at: keyframe.at).bringBack(keyframe.value), ease: keyframe.ease)
        }
    }

    func position(_ keyframes: [Keyframe<Point>]) -> [Keyframe<Point>] {
        keyframes.map { keyframe in
            Keyframe(at: keyframe.at, value: motion(at: keyframe.at).bringBack(keyframe.value), ease: keyframe.ease)
        }
    }

    func points(_ keyframes: [Keyframe<[Point]>]) -> [Keyframe<[Point]>] {
        keyframes.map { keyframe in
            let motion = self.motion(at: keyframe.at)
            return Keyframe(at: keyframe.at, value: keyframe.value.map { motion.bringBack($0) }, ease: keyframe.ease)
        }
    }

    // MARK: - Private
}
