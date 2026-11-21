//
//  ParentEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The space a clip's coordinates are in: its parent's map to output pixels, composed down the parent chain. A parent
// outside its window holds its values at the window's edge, and a storyline parent's map includes its transition
// motion. Each parent's values are its own, read by its own switch under motion blur (FRAMES-29). Opacity and reveal
// take no part.
struct ParentEvaluator: Sendable {
    // MARK: - Property
    private let sequence: ResolvedSequence
    private let clipEvaluator = ClipEvaluator()
    private let transitionSampler = TransitionSampler()

    // MARK: - Initializer
    init(sequence: ResolvedSequence) {
        self.sequence = sequence
    }

    // MARK: - Public
    func space(
        of clip: ResolvedClip,
        at time: Double
    ) -> ClipSpace {
        let frame = sequence.format.frame
        var chain: [ResolvedClip] = []
        var outer = ClipSpace(frame: frame)
        var next = clip.parent
        while let id = next {
            if let index = sequence.storyline.firstIndex(where: { $0.id == id }) {
                let entry = sequence.storyline[index]
                outer = ClipSpace(frame: frame, transform: transform(of: index, at: time), clock: entry.clock)
                break
            }
            // Resolve has checked that the id names a clip of the sequence and that the chain has no cycle.
            guard let parent = sequence.clips.first(where: { $0.id == id }) else { break }

            chain.append(parent)
            next = parent.parent
        }

        let parentSpace = chain.reversed().reduce(outer) { space, parent in
            let window = TimeRange(start: parent.start, end: parent.end)
            let transform = SampleInstant.reading(ownedBy: parent.isMotionBlurred, in: window, at: window.held(time)) {
                clipEvaluator.childTransform(of: parent, in: space.drawing(parent, of: sequence), at: $0)
            }
            return ClipSpace(frame: frame, transform: transform, clock: parent.clock)
        }

        return parentSpace.drawing(clip, of: sequence)
    }

    // MARK: - Private
    private func transform(
        of index: Int,
        at time: Double
    ) -> AffineTransform {
        let storyline = sequence.storyline
        let entry = storyline[index]
        let window = transitionSampler.drawnRange(of: index, in: storyline)
        let own = SampleInstant.reading(ownedBy: entry.isMotionBlurred, in: window, at: time) {
            entry.spaceTransform(at: $0)
        }
        let sample = transitionSampler.motion(of: index, in: storyline, at: SampleInstant.current?.frameTime ?? time)
        let motion = ItemPresentation(area: sequence.format.frame, opacity: 1, motion: sample.motion).transform

        return own.concatenating(motion)
    }
}
