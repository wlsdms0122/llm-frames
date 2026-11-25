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
        at time: SampleTime
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
            let transform = clipEvaluator.childTransform(
                of: parent,
                in: space.drawing(parent, of: sequence),
                at: parent.valueTime(in: time.sample)
            )
            return ClipSpace(frame: frame, transform: transform, clock: parent.clock)
        }

        return parentSpace.drawing(clip, of: sequence)
    }

    // The storyline clip's transition motion at the sample, which carries everything its picture draws and the space it
    // gives its children.
    func motion(
        ofStoryline index: Int,
        at sample: SampleInstant
    ) -> AffineTransform {
        let motion = transitionSampler.motion(of: index, in: sequence.storyline, at: sample).motion

        return ItemPresentation(area: sequence.format.frame, opacity: 1, motion: motion).transform
    }

    // MARK: - Private
    private func transform(
        of index: Int,
        at time: SampleTime
    ) -> AffineTransform {
        let storyline = sequence.storyline
        let own = storyline[index].spaceTransform(at: storyline.valueTime(ofEntry: index, in: time.sample))

        return own.concatenating(motion(ofStoryline: index, at: time.sample))
    }
}
