//
//  ParentEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Evaluates the space a clip's coordinates are in at a sequence time: P(t), its parent's map to output pixels, composed
// down the parent chain. Each parent is evaluated at the same instant whether or not it is visible, and outside its
// window it holds the values at the window's edge. A storyline parent's chain passes through its transition motion,
// held at the edges of its drawn range. Opacity and reveal take no part.
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
    // The chain is walked up to a storyline clip or an unparented clip, then composed from the outermost parent down.
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
                outer = ClipSpace(frame: frame, transform: transform(of: index, at: time), storyline: entry)
                break
            }
            // Resolve has checked that the id names a clip of the sequence and that the chain has no cycle.
            guard let parent = sequence.clips.first(where: { $0.id == id }) else { break }

            chain.append(parent)
            next = parent.parent
        }

        return chain.reversed().reduce(outer) { space, parent in
            let held = TimeRange(start: parent.start, end: parent.end).held(time)
            return ClipSpace(frame: frame, transform: clipEvaluator.childTransform(of: parent, in: space, at: held))
        }
    }

    // MARK: - Private
    // A storyline entry's map from its media pixels to output pixels: its conformed crop scaled to its box, its own
    // transform, then its transition motion. A solid's space is output pixels, carried by its transform and motion.
    // Its keyframes hold their edge values outside its drawn range, and so does its motion.
    private func transform(
        of index: Int,
        at time: Double
    ) -> AffineTransform {
        let entry = sequence.storyline[index]
        let frame = sequence.format.frame
        let sample = transitionSampler.motion(of: index, in: sequence.storyline, at: time)
        let motion = ItemPresentation(area: frame, opacity: 1, motion: sample.motion).transform
        let own = entry.presentation(at: time).transform.concatenating(motion)
        guard entry.media != nil else { return own }

        let crop = entry.crop(at: time)
        let box = Rectangle(x: 0, y: 0, width: entry.box.size.width, height: entry.box.size.height)
        return AffineTransform(translation: Point(x: -crop.x, y: -crop.y))
            .concatenating(AffineTransform(mapping: Size(width: crop.width, height: crop.height), onto: box))
            .concatenating(own)
    }
}
