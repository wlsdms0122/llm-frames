//
//  ResolvedStorylineClip+Presentation.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A storyline entry's own transform and opacity, which carry its box's own pixels into the frame. The transition
// motion is not part of it, since the outer item of its storyline picture carries that.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func presentation(at time: Double) -> ItemPresentation {
        ItemPresentation(
            box: box.size,
            anchor: box.anchor,
            values: KeyframedValues(
                position: box.position.value(at: time),
                scale: scale.value(at: time),
                rotation: rotation.value(at: time),
                opacity: opacity.opacity(at: time)
            ),
            motion: Motion()
        )
    }

    // MARK: - Private
}
